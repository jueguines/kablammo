require File.expand_path('../../lib/kablammo/git', __FILE__)
require 'digest/md5'

class Strategy

  REPO_REGEX = /git@github\.com:([^\/]*)\/(.*)\.git/
  include MongoMapper::Document

  cattr_accessor :strategies_location
  cattr_accessor :start_code_file_name
  cattr_accessor :start_code_file_location

  key :github_url, String
  key :name,       String, required: true, unique: true
  key :email,      String, required: true

  key :username,   String, required: true
  key :path,       String, required: true   # local path where we've cloned this

  validates_format_of :github_url, :allow_blank => true, :with => REPO_REGEX, message: 'Your repository url needs to be the ssh url.  e.g. git@github.com:my_username/myrepo.git'

  before_validation :update_repo_properties
  before_save :fetch_repo
  after_destroy :delete_repo

  def self.lookup(username)
    Strategy.where(name: username).first
  end

  def visible_name
    "#{name} by #{username}"
  end

  def launch
    print "Lauching #{name} by #{username}... "
    Bundler.with_clean_env do
      cmd = "cd '#{path}' && bundle exec ruby '#{@@start_code_file_location}' '#{name}'"
      @pid = Process.spawn(cmd)
      Process.detach(@pid)
    end
    puts "done (pid #{@pid})"
  end

  def kill
    puts "Should I kill process #{@pid}? #{process_exists? ? 'yes' : 'no'}"
    if process_exists?
      puts "Killing #{name} (#{@pid})"
      Process.kill 'KILL', @pid
    end
  end

  def process_exists?
    Process.getpgid @pid
    true
  rescue Errno::ESRCH
    false
  end

  def repo_is_local?
    github_url.nil? and path.is_local_dir? and 'local'.eql? username
  end

  def setup_as_local_repo
    self.username = 'local'
    self.path = github_url
    self.github_url = nil
    self.path
  end

  def update_repo_properties
    return setup_as_local_repo if github_url.is_local_dir?
    username = get_github_username(github_url)
    if username
      path = File.join( @@strategies_location, username, name )
      FileUtils.mkdir_p path
      self.username = username
      self.path = File.join path, get_github_repo_name(github_url)
    else
      puts "ERROR: Cannot get github username for repo: #{github_url}"
    end
  end

  #def github_url_valid?
  #  matches = github_url.to_s.match(REPO_REGEX)
  #  puts "Validating url #{github_url} #{matches}"
  #  !!(matches && matches[1])
  #end

  def gravatar
    author = Kablammo::Git::latest_author path
    if author
      email_address = author.email
      hash = Digest::MD5.hexdigest(email_address)
      "http://www.gravatar.com/avatar/#{hash}"
    else
      nil
    end
  end

  def repo_exists?
    File.exists? path
  end

  def delete_repo
    return if repo_is_local?
    if repo_exists?
      FileUtils.rm_rf(path)
    end
  end

  def fetch_repo(opts = {})
    return true if repo_is_local?
    # may want some error protection around this system command
    print "Getting latest code for #{visible_name}... "
    begin
      Kablammo::Git.pull_or_clone github_url, path
    rescue Git::GitExecuteError => ex
      begin
        puts
        print "Error getting code, trying harder (#{ex.message})... "
        delete_repo
        Kablammo::Git.pull_or_clone github_url, path
      rescue Git::GitExecuteError => ex2
        puts
        puts "Error: ", ex2
        self.errors.add :github_url, "Unable to clone url.  Check your Url and permissions"
        return false
      end
    end
    bundle = opts[:bundle_update] ? 'bundle update' : 'bundle'
    cmd = "cd '#{path}' && #{bundle} 2>&1"
    print "#{bundle.sub(/e$/, '')}ing... "
    Bundler.with_clean_env do
      bundle_output = `#{cmd}`
      status = $?
      if status.to_i != 0
        puts
        puts "Error running #{bundle}: #{status.to_s}"
        puts "$> #{cmd}"
        puts bundle_output
        return false
      end
    end
    puts 'done'
    true
  end

  def sha
    Kablammo::Git.sha(path)
  end

  private
  def get_github_repo_name(url)
    matches = url.match(REPO_REGEX)
    if matches && matches[2]
      matches[2]
    else
      nil
    end
  end

  def get_github_username(url)
    matches = url.match(REPO_REGEX)
    if matches && matches[1]
      matches[1].downcase
    else
      nil
    end
  end

  def spawn_file
    File.join(path, @@start_code_file_name)
  end

end
