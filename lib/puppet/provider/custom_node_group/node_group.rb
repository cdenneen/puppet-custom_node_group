Puppet::Type.type(:custom_node_group).provide(
  :node_group,
  parent: Puppet::Type.type(:node_group).provider(:https),
) do
  def self.instances
    super.select do |instance|
      description = instance.get(:description)
      description != :absent && description.include?('custom_node_group')
    end
  end
end
