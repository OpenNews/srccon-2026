require 'html-proofer'
require 'yaml'

namespace :test do

    desc "Check the built site with html-proofer"
    task :html_proofer do
        puts "Testing site with html-proofer..."

        # if no _site/, remind user to run bundle exec rake build first
        unless Dir.exist?('./_site')
            abort "❌ No _site/ directory found. Please run 'bundle exec rake build' first."
        end

        HTMLProofer.check_directory(
            "./_site",
            {
            disable_external: true,
            enforce_https: false,
            ignore_urls: [/^http:\/\/(localhost|127\.0\.0\.1)/],
            allow_hash_href: true
            }
        ).run
    end

    desc "Check common Liquid template issues"
    task :templates do
        puts "testing templates..."
        errors = []
        warnings = []
        
        # Find files with potentially broken Liquid templating
        Dir.glob('**/*.{html,md}', File::FNM_DOTMATCH).each do |file|
            next if file.start_with?('_site/', '.git/', 'vendor/', 'node_modules/')
            
            content = File.read(file)
            lines = content.split("\n")
            
            # Check each line for issues
            lines.each_with_index do |line, idx|
                line_num = idx + 1
                
                # Check for potentially unescaped {{ }} in href (without proper Liquid quotes)
                # This catches: href="{{variable}}" but NOT href="{{ page.url }}"
                if line =~ /href="\{\{[^}]+\}\}"/ && line !~ /href="\{\{\s*\w+\.\w+.*\}\}"/
                    warnings << "#{file}:#{line_num}: Possibly unescaped Liquid in href:\n      #{line.strip}"
                end
                
                # Check for site.root_url that should be page.root_url (common mistake)
                if line.include?('site.root_url') && !file.include?('_includes/prior_events.html')
                    errors << "#{file}:#{line_num}: Using site.root_url (should be page.root_url):\n      #{line.strip}"
                end
            end
            
            # Check for missing endif/endfor
            if_count = content.scan(/\{%\s*if\s+/).size
            endif_count = content.scan(/\{%\s*endif\s*%\}/).size
            if if_count != endif_count
                errors << "#{file}: Mismatched if/endif (#{if_count} if vs #{endif_count} endif)"
            end
            
            for_count = content.scan(/\{%\s*for\s+/).size
            endfor_count = content.scan(/\{%\s*endfor\s*%\}/).size
            if for_count != endfor_count
                errors << "#{file}: Mismatched for/endfor (#{for_count} for vs #{endfor_count} endfor)"
            end
        end
        
        if errors.any?
            puts "❌ Template errors:"
            errors.each { |e| puts "  - #{e}" }
            exit 1
        elsif warnings.any?
            puts "⚠️  Template warnings (may be false positives):"
            warnings.each { |w| puts "  - #{w}" }
            puts "\n💡 Review these to ensure Liquid syntax is correct"
        else
            puts "✅ Templates look good"
        end
    end

    desc "Check page-configuration props (section/permalink/title) in markdown"
    task :page_config do
        puts "testing page-configuration properties..."
        errors = []
        warnings = []
        
        Dir.glob('*.md').each do |file|
            next if file =~ /^[A-Z]+\.md$/
            
            content = File.read(file)
            if content =~ /\A---\s*\n(.*?)\n---\s*\n/m
                fm = YAML.safe_load($1)
                warnings << "#{file}: Missing 'section' field" unless fm['section']
                warnings << "#{file}: Missing 'permalink' field" unless fm['permalink']
                # warnings << "#{file}: Missing 'title' field" unless fm['title']
            else
                errors << "#{file}: No page-config args found"
            end
        end
        
        if errors.any?
            puts "❌ Page-config errors:"
            errors.each { |e| puts "  - #{e}" }
            exit 1
        elsif warnings.any?
            puts "⚠️  Page-config warnings:"
            warnings.each { |w| puts "  - #{w}" }
        else
            puts "✅ Page-config valid"
        end
    end

    desc "Check for placeholder content in built site"
    task :placeholders do
        puts "testing for placeholder content..."
        
        # Detect if this repo is srccon-site-starterkit
        if File.exist?('CNAME') && File.read('CNAME').include?('site-starterkit.srccon.org')
            puts "✅ Placeholder content check not applicable to the starter kit repo."
            next
        end

        placeholders = []
        
        Dir.glob('_site/**/*.html').each do |file|
            content = File.read(file)
            
            # Common placeholders
            %w[TODO YYYY DATES PLACE VENUE CITY PLS Nerd\ Church April\ 1 April\ 15].each do |placeholder|
                if content.include?(placeholder)
                    # Count occurrences
                    count = content.scan(/#{Regexp.escape(placeholder)}/).size
                    placeholders << "#{file}: Contains '#{placeholder}' (#{count}x)"
                end
            end
        end
        
        if placeholders.any?
            puts "⚠️  Found placeholder content:"
            placeholders.uniq.each { |p| puts "  - #{p}" }
        else
            puts "✅ No placeholder content found"
        end
    end

    desc "test for common accessibility issues"
    task :a11y do
        puts "testing accessibility..."
        issues = []
        
        Dir.glob('_site/**/*.html').each do |file|
            content = File.read(file)
            
            # test images have alt text
            content.scan(/<img[^>]+>/).each do |img|
                unless img.include?('alt=')
                    issues << "#{file}: Image without alt attribute: #{img[0..50]}..."
                end
            end
            
            # test for empty headings
            if content =~ /<h[1-6][^>]*>\s*<\/h[1-6]>/
                issues << "#{file}: Empty heading tag found"
            end
            
            # test lang attribute exists
            unless content =~ /<html[^>]+lang=/
                issues << "#{file}: Missing lang attribute on <html>"
            end
            
            # test for form inputs without labels
            content.scan(/<input[^>]+>/).each do |input|
                next if input.include?('type="hidden"')
                unless input.include?('aria-label=') || input.include?('id=')
                    issues << "#{file}: Input without label or aria-label: #{input[0..50]}..."
                end
            end
        end
        
        if issues.any?
            puts "⚠️  Accessibility issues (#{issues.size}):"
            issues.first(15).each { |i| puts "  - #{i}" }
            puts "  ... and #{issues.size - 15} more" if issues.size > 15
        else
            puts "✅ Basic accessibility tests passed"
        end
    end

    desc "test for performance issues"
    task :performance do
        puts "testing performance..."
        warnings = []
        
        Dir.glob('_site/**/*.html').each do |file|
            size = File.size(file)
            if size > 200_000
                warnings << "#{file}: Large HTML file (#{size / 1024}KB)"
            end
            
            content = File.read(file)
            
            # test for excessive inline styles
            inline_styles = content.scan(/<[^>]+style=/).size
            if inline_styles > 10
                warnings << "#{file}: #{inline_styles} inline style attributes (consider external CSS)"
            end
            
            # test for large base64 images
            if content.include?('data:image')
                warnings << "#{file}: Contains base64-encoded image data (hurts performance)"
            end
        end
        
        # test CSS file sizes
        Dir.glob('_site/**/*.css').each do |file|
            size = File.size(file)
            warnings << "#{file}: Large CSS file (#{size / 1024}KB)" if size > 100_000
        end
        
        if warnings.any?
            puts "⚠️  Performance warnings:"
            warnings.each { |w| puts "  - #{w}" }
        else
            puts "✅ Performance tests passed"
        end
    end

    # desc "Validate layout configuration and files"
    # task :layouts do
    #     require 'yaml'
        
    #     puts "Testing layout configuration..."
    #     errors = []
    #     warnings = []
        
    #     config = YAML.load_file('_config.yml')
        
    #     # Get all layout references from config
    #     layout_refs = []
    #     config['defaults'].each do |default|
    #         if default['values'] && default['values']['layout']
    #             layout_refs << default['values']['layout']
    #         end
    #     end
        
    #     # Check that layout files exist
    #     layout_refs.uniq.each do |layout|
    #         layout_file = "_layouts/#{layout}.html"
    #         unless File.exist?(layout_file)
    #             errors << "Layout '#{layout}' referenced in _config.yml but #{layout_file} does not exist"
    #         end
    #     end
        
    #     # Check all layout files are valid
    #     Dir.glob('_layouts/*.html').each do |layout_file|
    #         layout_name = File.basename(layout_file, '.html')
    #         content = File.read(layout_file)
            
    #         # Check for {{ content }} which is required in Jekyll layouts
    #         unless content.include?('{{ content }}')
    #             errors << "#{layout_file}: Missing required {{ content }} tag"
    #         end
            
    #         # Warn if layout is defined but not used in config
    #         unless layout_refs.include?(layout_name)
    #             warnings << "#{layout_file}: Layout exists but not referenced in _config.yml defaults"
    #         end
            
    #         # Check for basic structural elements
    #         unless content.include?('<!DOCTYPE') || content.include?('doctype')
    #             warnings << "#{layout_file}: Missing DOCTYPE declaration"
    #         end
    #     end
        
    #     # Test that both layout pathways work in built site
    #     if Dir.exist?('_site')
    #         layouts_found = {}
            
    #         Dir.glob('_site/**/*.html').each do |file|
    #             content = File.read(file)
                
    #             # Try to infer which layout was used based on structure
    #             # This is a heuristic check
    #             if content.include?('class="hub"')
    #                 layouts_found['simple_layout'] = true
    #             elsif content.include?('header-image')
    #                 layouts_found['layout_with_header_image'] = true
    #             end
    #         end
            
    #         # Check that we have examples of pages using each layout
    #         layout_refs.uniq.each do |layout|
    #             unless layouts_found[layout]
    #                 warnings << "Layout '#{layout}' is configured but no built pages appear to use it"
    #             end
    #         end
    #     end
        
    #     if errors.any?
    #         puts "❌ Layout errors:"
    #         errors.each { |e| puts "  - #{e}" }
    #         exit 1
    #     elsif warnings.any?
    #         puts "⚠️  Layout warnings:"
    #         warnings.each { |w| puts "  - #{w}" }
    #     else
    #         puts "✅ Layout configuration valid"
    #     end
    # end

    desc "Validate per-Session page structure"
    task :sessions do
        puts "testing session page structure..."
        errors = [] 
        warnings = []

        # Implement session-specific tests here
        # e.g., check for required frontmatter fields, URL structure, etc.
        # (Left as an exercise for future implementation)
        puts "✅ Session page structure tests not yet implemented."
        
        if errors.any?
            puts "❌ Session page structure errors:"
            errors.each { |e| puts "  - #{e}" }
            exit 1
        elsif warnings.any?
            puts "⚠️  Session page structure warnings:"
            warnings.each { |w| puts "  - #{w}" }
        else
            puts "✅ Session page structure tests passed"
        end
    end

    desc "Run all tests (comprehensive)"
    task :all => [
        :html_proofer,
        :templates,
        :page_config,
        :placeholders,
        :a11y,
        :performance,
        :git_hooks,
        :validate_yaml_task,
        :workflows
        # :layouts
    ] do
        puts "\n" + "=" * 60
        puts "✅ All validation tests passed!"
        puts "=" * 60
    end

    desc "Validate Git hooks are properly configured and functional"
    task :git_hooks do
        puts "testing git hooks configuration..."
        errors = []
        warnings = []
        
        # Check if .githooks directory exists and has pre-commit hook
        unless Dir.exist?('.githooks')
            errors << ".githooks directory not found"
        else
            unless File.exist?('.githooks/pre-commit')
                errors << ".githooks/pre-commit hook file not found"
            else
                # Check if pre-commit is executable
                unless File.executable?('.githooks/pre-commit')
                    errors << ".githooks/pre-commit is not executable (run: chmod +x .githooks/pre-commit)"
                end
                
                # Check content of pre-commit hook
                content = File.read('.githooks/pre-commit')
                unless content.include?('validate_yaml')
                    warnings << "pre-commit hook doesn't call validate_yaml task"
                end
                unless content.include?('_config.yml')
                    warnings << "pre-commit hook doesn't check for _config.yml changes"
                end
            end
        end
        
        # Check if user has configured git to use hooks
        hooks_path = `git config core.hooksPath`.strip
        if hooks_path.empty?
            warnings << "Git hooks not configured locally (run: git config core.hooksPath .githooks)"
        elsif hooks_path != '.githooks'
            warnings << "Git hooks path is '#{hooks_path}' instead of '.githooks'"
        end
        
        # Verify that _config.yml can be parsed successfully
        begin
            yaml_content = File.read('_config.yml')
            YAML.load_file('_config.yml')
        rescue => e
            errors << "_config.yml has syntax errors and could not be parsed: #{e.message}"
        end
        
        if errors.any?
            puts "❌ Git hooks errors:"
            errors.each { |e| puts "  - #{e}" }
            exit 1
        elsif warnings.any?
            puts "⚠️  Git hooks warnings:"
            warnings.each { |w| puts "  - #{w}" }
            puts "\n💡 Hooks are present but may need local setup: git config core.hooksPath .githooks"
        else
            puts "✅ Git hooks configured correctly"
        end
    end

    desc "Validate YAML validation task works correctly"
    task :validate_yaml_task do
        puts "testing validate_yaml task functionality..."
        errors = []
        
        # Test that the task exists
        unless Rake::Task.task_defined?(:validate_yaml)
            errors << "validate_yaml task not defined in Rakefile"
        end
        
        # Test that check_duplicate_keys_in_defaults function exists
        yaml_content = File.read('_config.yml')
        begin
            # Try to call the helper function
            dupes = check_duplicate_keys_in_defaults(yaml_content)
            if dupes.any?
                errors << "Found duplicate keys in _config.yml: #{dupes.join(', ')}"
            end
        rescue NameError => e
            errors << "check_duplicate_keys_in_defaults helper function not found: #{e.message}"
        end
        
        # Verify that validate_yaml is a prerequisite for key tasks
        [:check, :build].each do |task_name|
            if Rake::Task.task_defined?(task_name)
                task = Rake::Task[task_name]
                unless task.prerequisites.include?('validate_yaml')
                    errors << "#{task_name} task should have validate_yaml as prerequisite"
                end
            end
        end
        
        if errors.any?
            puts "❌ validate_yaml task errors:"
            errors.each { |e| puts "  - #{e}" }
            exit 1
        else
            puts "✅ validate_yaml task configured correctly"
        end
    end

    desc "Validate GitHub Actions workflows use validation tasks"
    task :workflows do
        puts "testing GitHub Actions workflows..."
        errors = []
        warnings = []
        
        # Check deploy workflow
        if File.exist?('.github/workflows/deploy.yml')
            content = File.read('.github/workflows/deploy.yml')
            unless content.include?('validate_yaml')
                errors << "deploy.yml workflow doesn't call validate_yaml before building"
            end
            unless content.include?('jekyll build')
                warnings << "deploy.yml workflow doesn't seem to build the site"
            end
        else
            warnings << ".github/workflows/deploy.yml not found"
        end
        
        # Check test workflow
        if File.exist?('.github/workflows/test.yml')
            content = File.read('.github/workflows/test.yml')
            unless content.include?('validate_yaml')
                errors << "test.yml workflow doesn't call validate_yaml before building"
            end
        else
            warnings << ".github/workflows/test.yml not found"
        end
        
        if errors.any?
            puts "❌ Workflow errors:"
            errors.each { |e| puts "  - #{e}" }
            exit 1
        elsif warnings.any?
            puts "⚠️  Workflow warnings:"
            warnings.each { |w| puts "  - #{w}" }
        else
            puts "✅ GitHub Actions workflows configured correctly"
        end
    end
end
