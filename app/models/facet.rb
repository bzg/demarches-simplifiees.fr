class Facet
  TYPE_DE_CHAMP = 'type_de_champ'
  TYPE_DE_CHAMP_PRIVATE = 'type_de_champ_private'

  def initialize(table:, column:, label: nil, virtual: false, type: :text, value_column: :value, filterable: true, classname: '', scope: '')
    @table = table
    @column = column
    @label = label || I18n.t(column, scope: [:activerecord, :attributes, :procedure_presentation, :fields, table])
    @classname = classname
    @virtual = virtual
    @type = type
    @scope = scope
    @value_column = value_column
    @filterable = filterable
  end

  attr_reader :table, :column, :label, :classname, :virtual, :type, :scope, :value_column, :filterable

  def ==(other)
    other.to_json == to_json
  end

  def to_json
    {
      table:, column:, label:, classname:, virtual:, type:, scope:, value_column:, filterable:
    }
  end

  def self.dossier_facets(procedure:)
    [
      new(table: 'self', column: 'created_at', type: :date),
      new(table: 'self', column: 'updated_at', type: :date),
      new(table: 'self', column: 'depose_at', type: :date),
      new(table: 'self', column: 'en_construction_at', type: :date),
      new(table: 'self', column: 'en_instruction_at', type: :date),
      new(table: 'self', column: 'processed_at', type: :date),
      *sva_svr_facets(procedure:, for_filters: true),
      new(table: 'self', column: 'updated_since', type: :date, virtual: true),
      new(table: 'self', column: 'depose_since', type: :date, virtual: true),
      new(table: 'self', column: 'en_construction_since', type: :date, virtual: true),
      new(table: 'self', column: 'en_instruction_since', type: :date, virtual: true),
      new(table: 'self', column: 'processed_since', type: :date, virtual: true),
      new(table: 'self', column: 'state', type: :enum, scope: 'instructeurs.dossiers.filterable_state', virtual: true)
    ].compact_blank
  end

  def self.facets(procedure:)
    facets = Facet.dossier_facets(procedure:)

    facets.push(
      new(table: 'user', column: 'email', type: :text),
      new(table: 'followers_instructeurs', column: 'email', type: :text),
      new(table: 'groupe_instructeur', column: 'id', type: :enum),
      new(table: 'avis', column: 'question_answer', filterable: false)
    )

    if procedure.for_individual
      facets.push(
        new(table: "individual", column: "prenom", type: :text),
        new(table: "individual", column: "nom", type: :text),
        new(table: "individual", column: "gender", type: :text)
      )
    end

    if !procedure.for_individual
      facets.push(
        new(table: 'etablissement', column: 'entreprise_siren', type: :text),
        new(table: 'etablissement', column: 'entreprise_forme_juridique', type: :text),
        new(table: 'etablissement', column: 'entreprise_nom_commercial', type: :text),
        new(table: 'etablissement', column: 'entreprise_raison_sociale', type: :text),
        new(table: 'etablissement', column: 'entreprise_siret_siege_social', type: :text),
        new(table: 'etablissement', column: 'entreprise_date_creation', type: :date)
      )

      facets.push(
        new(table: 'etablissement', column: 'siret', type: :text),
        new(table: 'etablissement', column: 'libelle_naf', type: :text),
        new(table: 'etablissement', column: 'code_postal', type: :text)
      )
    end

    facets.concat(procedure.types_de_champ_for_procedure_presentation
      .pluck(:type_champ, :libelle, :private, :stable_id)
      .reject { |(type_champ)| type_champ == TypeDeChamp.type_champs.fetch(:repetition) }
      .flat_map do |(type_champ, libelle, is_private, stable_id)|
        tdc = TypeDeChamp.new(type_champ:, libelle:, private: is_private, stable_id:)
        if is_private
          facets_for_type_de_champ_private(tdc)
        else
          facets_for_type_de_champ_public(tdc)
        end
      end)

    facets
  end

  def self.facets_for_type_de_champ_public(tdc)
    tdc.dynamic_type.search_paths.map do |path_struct|
      new(
        table: TYPE_DE_CHAMP,
        column: tdc.stable_id.to_s,
        label: path_struct[:libelle],
        type: TypeDeChamp.filter_hash_type(tdc.type_champ),
        value_column: path_struct[:path]
      )
    end
  end

  def self.facets_for_type_de_champ_private(tdc)
    tdc.dynamic_type.search_paths.map do |path_struct|
      new(
        table: TYPE_DE_CHAMP_PRIVATE,
        column: tdc.stable_id.to_s,
        label: path_struct[:libelle],
        type: TypeDeChamp.filter_hash_type(tdc.type_champ),
        value_column: path_struct[:path]
      )
    end
  end



  def self.sva_svr_facets(procedure:, for_filters: false)
    return if !procedure.sva_svr_enabled?

    i18n_scope = [:activerecord, :attributes, :procedure_presentation, :fields, :self]

    facets = []
    facets << new(table: 'self', column: 'sva_svr_decision_on',
                        type: :date,
                        label: I18n.t("#{procedure.sva_svr_decision}_decision_on", scope: i18n_scope),
                        classname: for_filters ? '' : 'sva-col')

    if for_filters
      facets << new(table: 'self', column: 'sva_svr_decision_before',
                        label: I18n.t("#{procedure.sva_svr_decision}_decision_before", scope: i18n_scope),
                        type: :date, virtual: true)
    end

    facets
  end
end
