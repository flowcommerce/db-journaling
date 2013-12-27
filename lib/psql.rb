load File.join(File.dirname(__FILE__), 'common.rb')

# A class to help run psql commands from the command line.
class Psql
  extend Common

  attr_reader :dbname, :host, :port, :username

  def initialize(dbname, opts = {})
    @dbname = dbname
    @username = opts.delete(:username)
    @host = opts.delete(:host)
    @port = opts.delete(:port)
    ensure_empty_opts(opts)
  end

  def in_schema(schema_name)
    schema_name ||= "public"
    query = <<-SQL
      set search_path to #{schema_name};
      #{yield}
    SQL
    unless schema_exists?(schema_name)
      query = "create schema #{schema_name};\n" + query
    end
    query
  end

  def execute(query)
    as_command(query) do |command|
      Common.run(command, true)
      if $?.exitstatus == 0
        true
      else
        error "psql command exited with nonzero status [#{$?.exitstatus}]."
        false
      end
    end
  end

  def run(query)
    as_command(query) do |command|
      Common.run(command)
    end
  end

  def schema_exists?(schema_name)
    result = run("select schema_name from information_schema.schemata where schema_name = '#{schema_name}';")
    result.include?(schema_name) && !result.include?("0 rows")
  end

  private
  def as_command(query)
    if `which psql` == ""
      error "You must have psql installed"
    elsif dbname.nil?
      error "You must specify the dbname"
    else
      command = "psql"
      command << " -U #{username}" unless username.nil?
      command << " -h #{host}" unless host.nil?
      command << " -p #{port}" unless port.nil?
      yield "#{command} -c \"#{sanitize(query)}\" #{dbname}"
    end
  end

  def sanitize(query)
    query.gsub("\"", "\\\"").gsub("\$", "\\\$")
  end

end