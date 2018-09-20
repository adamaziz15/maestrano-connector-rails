module Maestrano::Connector::Rails::Concerns::SubEntityBase
  extend ActiveSupport::Concern

  module ClassMethods
    def external?
      raise 'Not implemented'
    end

    def entity_name
      raise 'Not implemented'
    end

    def external_entity_name
      return entity_name if external?

      raise 'Forbidden call: cannot call external_entity_name for a connec entity'
    end

    def connec_entity_name
      return entity_name unless external?

      raise 'Forbidden call: cannot call connec_entity_name for an external entity'
    end

    def names_hash
      if external?
        {external_entity: entity_name.downcase}
      else
        {connec_entity: entity_name.downcase}
      end
    end

    # { 'External Entity'  => LalaMapper, 'Other external entity' => LiliMapper }
    # or { 'Connec Entity'  => LalaMapper, 'Other connec entity' => LiliMapper }
    def mapper_classes
      {}
    end

    # { 'External Entity'  => CreationLalaMapper, 'Other external entity' => CreationLiliMapper }
    # or { 'Connec Entity'  => CreationLalaMapper, 'Other connec entity' => CreationLiliMapper }
    def creation_mapper_classes
      mapper_classes
    end

    # {
    #   'External Entity' => ['organization_id'],
    #   'Other external entity' => ['an array of the connec reference fields']
    # }
    def references
      {}
    end
  end

  def map_to(name, entity, idmap = nil)
    first_time_mapped = self.class.external? ? idmap&.last_push_to_connec.nil? : idmap&.last_push_to_external.nil?
    mapper = first_time_mapped ? self.class.creation_mapper_classes[name] : self.class.mapper_classes[name]
    raise "Impossible mapping from #{self.class.entity_name} to #{name}" unless mapper

    if self.class.external?
      map_to_connec_helper(entity, mapper, self.class.references[name] || [])
    else
      map_to_external_helper(entity.merge(idmap: idmap), mapper)
    end
  end

  # Maps the entity received from external after a creation or an update and complete the received ids with the connec ones
  def map_and_complete_hash_with_connec_ids(external_hash, external_entity_name, connec_hash)
    return nil if connec_hash.empty?

    # As we don't know to which complex entity this sub entity is related to, we have to do a full scan of the entities to find the right one
    # Because we need the external_entities_names
    external_entity_instance = Maestrano::Connector::Rails::ComplexEntity.find_complex_entity_and_instantiate_external_sub_entity_instance(external_entity_name, @organization, @connec_client, @external_client, @opts)
    return nil unless external_entity_instance

    mapped_external_hash = external_entity_instance.map_to(self.class.connec_entity_name, external_hash)
    id_references = Maestrano::Connector::Rails::ConnecHelper.format_references(self.class.references[external_entity_name])

    Maestrano::Connector::Rails::ConnecHelper.merge_id_hashes(connec_hash, mapped_external_hash, id_references[:id_references])
  end
end
