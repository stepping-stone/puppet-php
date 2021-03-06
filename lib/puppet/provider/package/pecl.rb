require 'puppet/provider/package'

Puppet::Type.type(:package).newparam(:pipe)
Puppet::Type.type(:package).provide :pecl, :parent => Puppet::Provider::Package do
  desc "PHP PEAR support. By default uses the installed channels, but you can specify the path to a pear package via ``source``."

  has_feature :versionable
  has_feature :upgradeable

  case Facter.value(:operatingsystem)
    when "Solaris"
      commands :pearcmd => "/opt/coolstack/php5/bin/pecl"
    else
      commands :pearcmd => "pecl"
  end

  def self.pearlist(hash)
    command = [command(:pearcmd), "list"]

    begin
      list = execute(command).split("\n").collect do |set|
        if hash[:justme]
          if /^#{hash[:justme]}/i.match(set)
            if pearhash = pearsplit(set)
              pearhash[:provider] = :pearcmd
              pearhash
            else
              nil
            end
          else
            nil
          end
        else
          if pearhash = pearsplit(set)
            pearhash[:provider] = :pearcmd
            pearhash
          else
            nil
          end
        end
      end.reject { |p| p.nil? }
    rescue Puppet::ExecutionFailure => detail
      raise Puppet::Error, "Could not list pears: %s" % detail
    end

    if hash[:justme]
      return list.shift
    else
      return list
    end
  end

  def self.pearsplit(desc)
    desc.strip!

    case desc
    when /^INSTALLED/ then return nil
    when /No packages installed from channel/i then return nil
    when /^=/ then return nil
    when /^PACKAGE/ then return nil
    when /^(\S+)\s+(\S+)\s+\S+/ then
      name = $1
      version = $2

      return {
        :name => name,
        :ensure => version
      }
    else
      Puppet.warning "Could not match %s" % desc
      nil
    end
  end

  def self.instances
    pearlist(:local => true).collect do |hash|
      new(hash)
    end
  end

  def name
    super.sub('pecl-', '')
  end

  def install(useversion = true)
    command = ["upgrade"]

    if source = @resource[:source]
      command << source
    else
      if (! @resource.should(:ensure).is_a? Symbol) and useversion
        command << "#{self.name}-#{@resource.should(:ensure)}"
      else
        command << self.name
      end
    end

    if pipe = @resource[:pipe]
        command << "<<<"
        command << @resource[:pipe]
    end

    pearcmd(*command)
  end

  def latest
    version = ''
    command = [command(:pearcmd), "remote-info", self.name]
    list = execute(command).each_line do |set|
      if set =~ /^Latest/
        version = set.split[1]
      end
    end

    return version
  end

  def query
    self.class.pearlist(:justme => self.name)
  end

  def uninstall
    output = pearcmd "uninstall", self.name
    if output =~ /^uninstall ok/
    else
      raise Puppet::Error, output
    end
  end

  def update
    self.install(false)
  end
end
