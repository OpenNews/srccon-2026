require 'jekyll'
require 'yaml'
require 'fileutils'

# Load test:* tasks from separate file
Dir.glob('tasks/*.rake').each { |r| load r }

# Load deployment vars from _config.yml
def deployment_config
  return @deployment_config if @deployment_config
  
  unless File.exist?('_config.yml')
    abort "❌ _config.yml not found. Are you in the project root directory?"
  end
  
  begin
    config = YAML.safe_load_file('_config.yml')
    @deployment_config = config['deployment'] || {}
  rescue => e
    abort "❌ Error loading _config.yml: #{e.message}"
  end
end

# Helper: check for duplicate keys within each scope of the defaults section
def check_duplicate_keys_in_defaults(yaml_content)
  in_defaults = false
  in_scope = false
  in_values = false
  values_indent = nil
  scope_keys = []
  scope_path = nil
  all_duplicate_keys = []
  
  yaml_content.each_line do |line|
    # Track when we enter/exit the defaults section
    if line =~ /^defaults:/
      in_defaults = true
      next
    elsif in_defaults && line =~ /^[a-z_]/
      break # exited defaults section
    end
    
    next unless in_defaults
    
    # Look for new scope entry
    if line =~ /^\s+-\s+scope:/ || line =~ /^\s+scope:/
      # Check previous scope for duplicates before starting new one
      if scope_keys.any?
        duplicate_keys = scope_keys.select { |k| scope_keys.count(k) > 1 }.uniq
        if duplicate_keys.any?
          scope_label = scope_path.nil? || scope_path.empty? ? "empty path scope" : "scope '#{scope_path}'"
          all_duplicate_keys.concat(duplicate_keys.map { |k| "#{k} (in #{scope_label})" })
        end
      end
      
      in_scope = true
      in_values = false
      scope_keys = []
      scope_path = nil
    end
    
    # Capture the path for this scope
    if in_scope && line =~ /^\s+path:\s*["']?([^"']*)["']?\s*$/
      scope_path = $1
    end
    
    # Look for values section within scope
    if in_scope && line =~ /^(\s+)values:\s*$/
      in_values = true
      values_indent = $1.length + 2 # keys should be indented more than "values:"
      next
    end
    
    # Extract keys from values section
    if in_values
      current_indent = line[/^(\s*)/].length
      
      # Exit values section if we dedent
      if line.strip != '' && current_indent < values_indent
        in_values = false
        in_scope = false
        next
      end
      
      # Extract key name (word characters followed by colon)
      if line =~ /^\s{#{values_indent}}(\w+):/
        scope_keys << $1
      end
    end
  end
  
  # Check the last scope for duplicates
  if scope_keys.any?
    duplicate_keys = scope_keys.select { |k| scope_keys.count(k) > 1 }.uniq
    if duplicate_keys.any?
      scope_label = scope_path.nil? || scope_path.empty? ? "empty path scope" : "scope '#{scope_path}'"
      all_duplicate_keys.concat(duplicate_keys.map { |k| "#{k} (in #{scope_label})" })
    end
  end
  
  all_duplicate_keys
end

# Validate YAML syntax and structure before any tasks that depend on config
desc "Validate _config.yml has valid YAML syntax and no duplicate keys"
task :validate_yaml do
  unless File.exist?('_config.yml')
    abort "❌ _config.yml not found. Are you in the project root directory?"
  end
  
  # Check for valid YAML syntax
  begin
    YAML.safe_load_file('_config.yml')
  rescue => e
    abort "❌ Invalid YAML syntax in _config.yml: #{e.message}"
  end
  
  # Check for duplicate keys (YAML parser silently ignores these)
  yaml_content = File.read('_config.yml')
  duplicate_keys = check_duplicate_keys_in_defaults(yaml_content)
  if duplicate_keys.any?
    abort "❌ Duplicate keys found in _config.yml defaults: #{duplicate_keys.join(', ')}"
  end
end

# Default task
task default: [:validate_yaml, :build, :check, :serve]

desc "Validate configuration has been updated from template defaults"
task :check => :validate_yaml do
  puts "Validating _config.yml configuration..."
  
  config = YAML.safe_load_file('_config.yml')
  
  unless config['defaults'].is_a?(Array)
    abort "❌ _config.yml is missing 'defaults' array"
  end
  
  default_scope = config['defaults'].find { |d| d['scope'] && d['scope']['path'] == '' }
  unless default_scope && default_scope['values']
    abort "❌ _config.yml is missing default scope with empty path"
  end
  
  defaults = default_scope['values']
  
  errors = []
  warnings = []
  
  # Check for placeholder values that need updating
  errors << "root_url is still set to 'https://2025.srccon.org'" if defaults['root_url'] == 'https://2025.srccon.org'
  errors << "event_name is still set to 'SRCCON YYYY'" if defaults['event_name'] == 'SRCCON YYYY'
  errors << "event_date is still 'DATES' placeholder" if defaults['event_date'] == 'DATES'
  errors << "event_place is still 'PLACE' placeholder" if defaults['event_place'] == 'PLACE'
  errors << "form_link is still set to the demo Airtable URL" if defaults['form_link'].to_s.include?('TK')
  errors << "session_deadline is still set to April Fools placeholder" if defaults['session_deadline'].to_s.include?('April 1')
  errors << "session_confirm is still set to Tax Day placeholder" if defaults['session_confirm'].to_s.include?('April 15')
  
  cname_content = File.read('CNAME').strip
  errors << "CNAME file still has demo site URL, update with your event." if cname_content.include?('2025.srccon.org')
  
  warnings << "event_timezone_offset is empty (needed for live sessions feature)" if defaults['event_timezone_offset'].nil? || defaults['event_timezone_offset'].empty?
  warnings << "google_analytics_id is empty (no tracking will be enabled)" if defaults['google_analytics_id'].nil? || defaults['google_analytics_id'].empty?
  
  # verify prices are in $XXX format
  [
    defaults['price_base'], 
    defaults['price_med'], 
    defaults['price_full'], 
    defaults['price_stipend']
  ].each do |price|
    cost = price.to_s.gsub(/^\$(\d{3})$/) { |m| $1 } # extract digits
    warnings << "Ticket price #{price} has no dollar-sign prefix" unless price.to_s.start_with?('$')
    warnings << "Ticket price #{price} is not three digits" if cost && (cost.to_i < 100 || cost.to_i > 999)
  end
    
  if errors.any?
    puts "\n❌ Configuration Errors (MUST FIX):"
    errors.each { |e| puts "  - #{e}" }
  end
  
  if warnings.any?
    puts "\n⚠️  Configuration Warnings:"
    warnings.each { |w| puts "  - #{w}" }
  end
  
  if errors.empty?
    puts "\n✅ Configuration looks good!"
  end
end

desc "Build the Jekyll site"
task :build => :validate_yaml do
  puts "Building Jekyll site..."
  options = {
    "source" => ".",
    "destination" => "./_site"
  }
  Jekyll::Site.new(Jekyll.configuration(options)).process
end

desc "Clean the build directory"
task :clean do
  puts "Cleaning _site directory..."
  FileUtils.rm_rf(['_site', '.jekyll-cache', '.jekyll-metadata'])
end

desc "Build and serve the site locally"
task :serve do
  puts "Starting Jekyll server..."
  sh "bundle exec jekyll serve"
end

namespace :deploy do
  desc "Run all pre-deployment checks"
  task :precheck => [:validate_yaml, :check, :build, 'test:all'] do
    puts "\n✅ All pre-deployment checks passed!"
    puts "\nDeploy with:"
    puts "  rake deploy:staging          # Dry-run to staging"
    puts "  rake deploy:staging:real     # Actually deploy to staging"
    puts "  rake deploy:production       # Dry-run to production"
    puts "  rake deploy:production:real  # Actually deploy to production"
  end
  
  # Common S3 sync arguments
  S3_ARGS = "--delete --cache-control 'public, max-age=3600'"

  desc "Deploy to staging (dry-run by default; mostly run by GitHub Actions)"
  namespace :staging do
    task :default => :dryrun
    
    desc "Dry-run staging deploy"
    task :dryrun => :build do
      config = deployment_config
      staging_bucket = config['staging_bucket'] || "staging.#{config['bucket']}"
      abort "❌ Staging bucket not configured in _config.yml deployment section" unless staging_bucket
      
      puts "[DRY RUN] Deploying to staging bucket: #{staging_bucket}..."
      sh "aws s3 sync _site/ s3://#{staging_bucket} --dryrun #{S3_ARGS}"
      puts "\n✅ Dry-run complete. To deploy for real, run: rake deploy:staging:real"
    end

    desc "Real staging deploy (with confirmation)"
    task :real => :precheck do
      config = deployment_config
      staging_bucket = config['staging_bucket'] || "staging.#{config['bucket']}"
      abort "❌ Staging bucket not configured in _config.yml deployment section" unless staging_bucket
      
      puts "⚠️  Deploying to STAGING: #{staging_bucket}"
      print "Continue? (y/N) "

      response = STDIN.gets.chomp
      abort "Deployment cancelled" unless response.downcase == 'y'
      
      puts "Deploying to staging bucket: #{staging_bucket}..."
      sh "aws s3 sync _site/ s3://#{staging_bucket} #{S3_ARGS}"
      puts "\n✅ Successfully deployed to staging!"
    end
  end

  desc "Deploy to production (dry-run by default; mostly run by GitHub Actions)"
  namespace :production do
    task :default => :dryrun

    desc "Dry-run production deploy"
    task :dryrun => :build do
      config = deployment_config
      prod_bucket = config['bucket']
      cloudfront_dist = config['cloudfront_distribution_id']
      abort "❌ Production bucket not configured in _config.yml deployment section" unless prod_bucket
      
      puts "[DRY RUN] Deploying to production bucket: #{prod_bucket}..."
      sh "aws s3 sync _site/ s3://#{prod_bucket} --dryrun #{S3_ARGS}"
      
      if cloudfront_dist && !cloudfront_dist.empty?
        puts "\n[DRY RUN] Would invalidate CloudFront: #{cloudfront_dist}"
      else
        puts "\n⚠️  No CloudFront distribution configured (cache won't be invalidated)"
      end
      
      puts "\n✅ Dry-run complete. To deploy for real, run: rake deploy:production:real"
    end

    desc "Real production deploy (with confirmation)"
    task :real => :precheck do
      config = deployment_config
      prod_bucket = config['bucket']
      cloudfront_dist = config['cloudfront_distribution_id']
      abort "❌ Production bucket not configured in _config.yml deployment section" unless prod_bucket
      
      puts "🚨 DEPLOYING TO PRODUCTION: #{prod_bucket}"
      print "Are you absolutely sure? (yes/N) "
      response = STDIN.gets.chomp
      abort "Deployment cancelled" unless response == 'yes'
      
      puts "\nDeploying to production bucket: #{prod_bucket}..."
      sh "aws s3 sync _site/ s3://#{prod_bucket} #{S3_ARGS}"
      
      if cloudfront_dist && !cloudfront_dist.empty?
        puts "\nInvalidating CloudFront distribution: #{cloudfront_dist}..."
        sh "aws cloudfront create-invalidation --distribution-id #{cloudfront_dist} --paths '/*'"
        puts "\n✅ CloudFront cache invalidated"
      else
        puts "\n⚠️  Skipping CloudFront invalidation (not configured)"
      end
      
      puts "\n🎉 Successfully deployed to production!"
    end
  end
end

namespace :git do
  desc "Install Git hooks for pre-commit validation"
  task :install_hooks do
    hook_source = File.join(__dir__, 'tasks', 'pre-commit')
    hook_dest = File.join(__dir__, '.git', 'hooks', 'pre-commit')
    
    unless File.exist?(hook_source)
      abort "❌ Hook source not found: #{hook_source}"
    end
    
    # Copy the hook
    FileUtils.cp(hook_source, hook_dest)
    FileUtils.chmod(0755, hook_dest)
    
    puts "✅ Pre-commit hook installed successfully!"
    puts "   Config validation will now run automatically before each commit."
    puts "   To bypass: git commit --no-verify"
  end
  
  desc "Uninstall Git hooks"
  task :uninstall_hooks do
    hook_dest = File.join(__dir__, '.git', 'hooks', 'pre-commit')
    
    if File.exist?(hook_dest)
      FileUtils.rm(hook_dest)
      puts "✅ Pre-commit hook removed"
    else
      puts "ℹ️  No pre-commit hook found"
    end
  end
end
