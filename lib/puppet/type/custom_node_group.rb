Puppet::Type.newtype(:custom_node_group) do
  desc 'The node_group type creates and manages node groups for the PE Node Manager'
  ensurable
  newparam(:name, namevar: true) do
    desc 'This is the common name for the node group'
  end
  newparam(:purge_behavior) do
    desc 'Whether or not to remove data or class parameters not specified'
    newvalues(:none, :data, :classes, :rule, :all)
    defaultto :all
  end
  newproperty(:id) do
    desc 'The ID of the group'
    validate do |_value|
      raise('ID is read-only')
    end
  end
  newproperty(:override_environment, boolean: true) do
    desc 'Override parent environments'
    munge do |value|
      Puppet::Coercion.boolean(value).to_s.to_sym
    end
  end
  newproperty(:parent) do
    desc 'The ID of the parent group'
    # newvalues(/^\h{8}-\h{4}-\h{4}-\h{4}-\h{12}$/, 'AP Application Custom Node Groups')
    defaultto 'AP Application Custom Node Groups'
  end
  newproperty(:variables) do
    desc 'Variables set this group\'s scope'
    validate do |value|
      raise('Variables must be supplied as a hash') unless value.is_a?(Hash)
    end
  end
  newproperty(:rule, array_matching: :all) do
    desc 'Match conditions for this group'
    def should
      case @resource[:purge_behavior]
      when :rule, :all
        super
      else
        a = @resource.property(:rule).retrieve || {}
        b = shouldorig
        aorig = a.map(&:clone)
        atmp = a.map(&:clone)
        # check if the node classifer has any rules defined before attempting merge.
        if a.length >= 2
          if (a[0] == 'or') && (a[1][0] == 'or') || (a[1][0] == 'and')
            # Merging both rules and pinned nodes
            if (b[0] == 'or') && (b[1][0] == 'or') || (b[1][0] == 'and')
              # b has rules to merge
              rules = (atmp[1] + b[1].drop(1)).uniq
              atmp[1] = rules
              pinned = (b[2, b.length] + atmp[2, atmp.length]).uniq
              merged = (atmp + pinned).uniq
            elsif ((b[0] == 'and') || (b[0] == 'or')) && PuppetX::Node_manager::Common.factcheck(b)
              # b only has rules to merge
              rules = (atmp[1] + b.drop(1)).uniq
              atmp[1] = rules
              merged = atmp
            else
              pinned = (b[1, b.length] + atmp[2, atmp.length]).uniq
              merged = (atmp + pinned).uniq
            end
          elsif (b[0] == 'or') && (b[1][0] == 'or') || (b[1][0] == 'and')
            # Merging both rules and pinned nodes
            b[1] # no rules to merge on a side
            pinned = (b[2, b.length] + a[1, a.length]).uniq
            merged = (b + pinned).uniq
          elsif ((a[0] == 'and') || (a[0] == 'or')) && PuppetX::Node_manager::Common.factcheck(a)
            # a only has fact rules
            if (b[0] == 'or') && !PuppetX::Node_manager::Common.factcheck(b)
              # b only has pinned nodes
              temp = ['or']
              temp[1] = atmp
              merged = (temp + b[1, b.length]).uniq
            else
              # b only has rules
              merged = (a + b.drop(1)).uniq
            end
          elsif (a[0] == 'or') && (a[1][1] == 'name')
            # a only has pinned nodes
            if (b[0] == 'or') && !PuppetX::Node_manager::Common.factcheck(b)
              # b only has pinned nodes
              merged = (b + a.drop(1)).uniq
            else
              # b only has rules
              temp = ['or']
              temp[1] = b
              merged = (temp + atmp[1, atmp.length]).uniq
            end
          else
            # default fall back.
            merged = (b + a.drop(1)).uniq
          end
          if merged == aorig
            # values are the same, returning orginal value"
            aorig
          else
            merged
          end
        else
          b
        end
      end
    end

    def insync?(is)
      is == should
    end
  end
  newproperty(:environment) do
    desc 'Environment for this group'
    defaultto :production
    validate do |value|
      raise('Invalid environment name') unless value =~ (%r{\A[a-z0-9_]+\Z}) || (value == 'agent-specified')
    end
  end
  newproperty(:classes) do
    desc 'Classes applied to this group'
    defaultto {}
    validate do |value|
      raise('Classes must be supplied as a hash') unless value.is_a?(Hash)
    end
    # Need to deep sort hashes so they be evaluated equally
    munge do |value|
      PuppetX::Node_manager::Common.sort_hash(value)
    end
    def should
      case @resource[:purge_behavior]
      when :classes, :all
        super
      else
        a = @resource.property(:classes).retrieve || {}
        b = shouldorig.first
        merged = a.merge(b) { |_k, x, y| x.merge(y) }
        PuppetX::Node_manager::Common.sort_hash(merged)
      end
    end
  end
  newproperty(:data) do
    desc 'Data applied to this group'
    # defaultto {}
    validate do |value|
      raise('Data must be supplied as a hash') unless value.is_a?(Hash)
    end
    # Need to deep sort hashes so they be evaluated equally
    munge do |value|
      PuppetX::Node_manager::Common.sort_hash(value)
    end
    def should
      case @resource[:purge_behavior]
      when :data, :all
        super
      else
        a = @resource.property(:data).retrieve || {}
        b = shouldorig.first
        merged = a.merge(b) { |_k, x, y| x.merge(y) }
        PuppetX::Node_manager::Common.sort_hash(merged)
      end
    end
  end
  newproperty(:description) do
    desc 'Description of this group'
    # newvalues(/custom_node_group/i)
    defaultto 'custom_node_group'
    munge do |value|
      (value == default) ? value : "custom_node_group: #{value}"
    end
  end

  autorequire(:custom_node_group) do
    self[:parent] if @parameters.include? :parent
  end
end
