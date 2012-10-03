require 'cucumber/formatter/console'
require 'cucumber/formatter/ansicolor'
require 'cucumber/formatter/io'
require 'ruby-progressbar'

module Cucumber
  module Formatter
    class Fuubar
      include Console
      include Io

      attr_reader :step_mother

      def initialize(step_mother, path_or_io, options)
        @step_mother, @io, @options = step_mother, ensure_io(path_or_io, "fuubar"), options
        @step_count = @issues_count = 0
      end

      def after_features(features)
        @state = :red if step_mother.scenarios(:failed).any?
        @io.puts
        @io.puts
        print_summary(features)
      end

      def before_features(features)
        @step_count = get_step_count(features)
        @progress_bar = ProgressBar.create(:format => ' %c/%C |%w>%i| %e ', :total => @step_count, :output => @io)
      end

      def before_background(background)
        @in_background = true
      end

      def after_background(background)
        @in_background = false
      end

      def before_feature_element(feature_element)
        @scenario_outline = true if feature_element.class == Cucumber::Ast::ScenarioOutline
      end

      def after_feature_element(feature_element)
        @scenario_outline = false if feature_element.class == Cucumber::Ast::ScenarioOutline
      end

      def after_step_result(keyword, step_match, multiline_arg, status, exception, source_indent, background, file_colon_line)
        return if @in_background || @scenario_outline
        @state = :red if status == :failed
        if exception and [:failed, :undefined].include? status
          print_exception(exception, status)
        end
        progress(status)
      end

      def before_examples(examples)
        @is_example = true
      end

      def after_examples(examples)
        @is_example = false
      end

      def before_table_row(table_row)
        if @is_example && table_row.is_a?(Cucumber::Ast::OutlineTable::ExampleRow) && table_row.scenario_outline && table_row.scenario_outline.instance_variable_get("@background").instance_variable_get("@steps")
          progress(:passed, table_row.scenario_outline.instance_variable_get("@background").instance_variable_get("@steps").count)
        end
      end

      def after_table_row(table_row)
        if @is_example && table_row.is_a?(Cucumber::Ast::OutlineTable::ExampleRow) && table_row.scenario_outline
          if table_row.exception and [:failed, :undefined].include? table_row.status
            print_exception(table_row.exception, table_row.status)
          else
            progress(:passed, table_row.scenario_outline.instance_variable_get("@steps").count)
          end
        end
      end

      protected
        def print_exception(exception,status)
          @io.print "\e[K" if colors_enabled?
          @issues_count += 1
          @io.puts
          @io.puts "#{@issues_count})"
          super(exception, status, 2)
          @io.puts
          @io.flush
        end
        
        def state
          @state ||= :green
        end

        def print_summary(features)
          print_stats(features, @options)
          print_snippets(@options)
          print_passing_wip(@options)
        end

        COLORS = { :green =>  "\e[32m", :yellow => "\e[33m", :red => "\e[31m" }

        def progress(status = 'passed', count = 1)
          with_colors(COLORS[state]) do
            @progress_bar.progress += count
          end
        end

        def get_step_count(features)
          count = 0
          features = features.instance_variable_get("@features")
          features.each do |feature|
            background_size = 0
            if feature.instance_variable_get("@background")
              background = feature.instance_variable_get("@background")
              background.init
              background_steps = background.instance_variable_get("@steps").instance_variable_get("@steps")
            end
            feature.instance_variable_get("@feature_elements").each do |scenario|
              scenario.init
              steps = scenario.instance_variable_get("@steps").instance_variable_get("@steps")
              scenario_size = steps.size
              if background_steps && scenario.is_a?(Cucumber::Ast::ScenarioOutline)
                background_size = background_steps.size
              end
              examples = scenario.instance_variable_get("@examples_array")
              if examples
                examples.each do |example|
                  example_matrix = example.instance_variable_get("@outline_table").instance_variable_get("@cell_matrix")
                  count += (scenario_size + background_size)*(example_matrix.size - 1)
                end
              else
                count += scenario_size
              end
            end
          end
          return count
        end

        def with_colors(color, &block)
          @io.print color if colors_enabled?
          yield
          @io.print "\e[0m" if colors_enabled?
        end

        def colors_enabled?
          Cucumber::Term::ANSIColor.coloring?
        end
    end
  end
end
