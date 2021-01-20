describe InstructeursImportService do
  describe '#import' do
    let(:service) { InstructeursImportService.new }
    let(:procedure) { create(:procedure) }

    let(:procedure_groupes) do
      procedure
        .groupe_instructeurs
        .map { |gi| [gi.label, gi.instructeurs.map(&:email)] }
    end

    subject { service.import(procedure, lines) }

    context 'nominal case' do
      let(:lines) do
        [
          { "groupe" => "Auvergne Rhone-Alpes", "email" => "john@lennon.fr" },
          { "groupe" => "  Occitanie  ", "email" => "paul@mccartney.uk" },
          { "groupe" => "Occitanie", "email" => "ringo@starr.uk" }
        ]
      end

      it 'imports' do
        errors = subject

        expect(procedure_groupes).to match_array([
          ["Auvergne Rhone-Alpes", ["john@lennon.fr"]],
          ["Occitanie", ["paul@mccartney.uk", "ringo@starr.uk"]],
          ["défaut", []]
        ])

        expect(errors).to match_array([])
      end
    end

    context 'when group already exists' do
      let!(:gi) { create(:groupe_instructeur, label: 'Occitanie', procedure: procedure) }
      let(:lines) do
        [
          { "groupe" => "Occitanie", "email" => "ringo@starr.uk" }
        ]
      end

      before do
        gi.instructeurs << create(:instructeur, email: 'george@harisson.uk')
      end

      it 'adds instructeur to existing groupe' do
        subject

        expect(procedure_groupes).to match_array([
          ["Occitanie", ["george@harisson.uk", "ringo@starr.uk"]],
          ["défaut", []]
        ])
      end
    end

    context 'when an email is malformed' do
      let(:lines) do
        [
          { "groupe" => "Occitanie", "email" => "paul" },
          { "groupe" => "Occitanie", "email" => "  Paul@mccartney.uk " },
          { "groupe" => "Occitanie", "email" => "ringo@starr.uk" }
        ]
      end

      it 'ignores or corrects' do
        errors = subject

        expect(procedure_groupes).to match_array([
          ["Occitanie", ["paul@mccartney.uk", "ringo@starr.uk"]],
          ["défaut", []]
        ])

        expect(errors).to match_array(['paul'])
      end
    end

    context 'when an instructeur already exists' do
      let!(:instructeur) { create(:instructeur) }
      let(:lines) do
        [
          { "groupe" => "Occitanie", "email" => instructeur.email },
          { "groupe" => "Occitanie", "email" => "ringo@starr.uk" }
        ]
      end

      it 'reuses instructeur' do
        subject

        expect(procedure_groupes).to match_array([
          ["Occitanie", [instructeur.email, "ringo@starr.uk"]],
          ["défaut", []]
        ])
      end
    end

    context 'when there are 2 emails of same instructeur to be imported' do
      let(:lines) do
        [
          { "groupe" => "Occitanie", "email" => "ringo@starr.uk" },
          { "groupe" => "Occitanie", "email" => "ringo@starr.uk" }
        ]
      end

      it 'ignores duplicated instructeur' do
        subject

        expect(procedure_groupes).to match_array([
          ["Occitanie", ["ringo@starr.uk"]],
          ["défaut", []]
        ])
      end
    end

    context 'when label of group is empty' do
      let(:lines) do
        [
          { "groupe" => "", "email" => "ringo@starr.uk" },
          { "groupe" => " ", "email" => "paul@starr.uk" }
        ]
      end

      it 'ignores instructeur' do
        errors = subject

        expect(procedure_groupes).to match_array([
          ["défaut", []]
        ])

        expect(errors).to match_array([
          'ringo@starr.uk',
          'paul@starr.uk'
        ])
      end
    end
  end
end
