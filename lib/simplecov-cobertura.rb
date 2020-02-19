require 'simplecov'

require 'rexml/document'
require 'rexml/element'

require_relative 'simplecov-cobertura/version'

module SimpleCov
  module Formatter
    class CoberturaFormatter
      RESULT_FILE_NAME = 'coverage.xml'
      DTD_URL = 'http://cobertura.sourceforge.net/xml/coverage-04.dtd'

      def format(result)
        xml_doc = result_to_xml result
        result_path = File.join(SimpleCov.coverage_path, RESULT_FILE_NAME)

        formatter = REXML::Formatters::Pretty.new
        formatter.compact = true
        string_io = StringIO.new
        formatter.write(xml_doc, string_io)

        xml_str = string_io.string
        File.write(result_path, xml_str)
        puts "Coverage report generated for #{result.command_name} to #{result_path}"
        xml_str
      end

      private
      def result_to_xml(result)
        doc = REXML::Document.new set_xml_head
        doc.context[:attribute_quote] = :quote
        doc.add_element REXML::Element.new('coverage')
        coverage = doc.root

        set_coverage_attributes(coverage, result)

        coverage.add_element(sources = REXML::Element.new('sources'))
        sources.add_element(source = REXML::Element.new('source'))
        source.text = SimpleCov.root

        coverage.add_element(packages = REXML::Element.new('packages'))

        if result.groups.empty?
          groups = {File.basename(SimpleCov.root) => result.files}
        else
          groups = result.groups
        end

        groups.map do |name, files|
          packages.add_element(package = REXML::Element.new('package'))
          set_package_attributes(package, name, files)

          package.add_element(classes = REXML::Element.new('classes'))

          files.each do |file|
            classes.add_element(class_ = REXML::Element.new('class'))
            set_class_attributes(class_, file)

            class_.add_element(REXML::Element.new('methods'))
            class_.add_element(lines = REXML::Element.new('lines'))

            file.lines.each do |file_line|
              if file_line.covered? || file_line.missed?
                lines.add_element(line = REXML::Element.new('line'))
                set_line_attributes(line, file_line)
              end
            end

            file.branches.each do |file_branch|
              if file_branch.covered? || file_branch.missed?
                branches.add_element(branch = REXML::Element.new('branch'))
                set_branch_attributes(branch, file_branch)
              end
            end
          end
        end

        doc
      end

      def set_coverage_attributes(coverage, result)
        coverage.attributes['line-rate'] = (result.covered_percent/100).round(2).to_s
        coverage.attributes['lines-covered'] = result.covered_lines.to_s
        coverage.attributes['lines-valid'] = (result.covered_lines + result.missed_lines).to_s
        # coverage.attributes['branch-rate'] = ((result&.branch_covered_percent || 0)/100).round(2).to_s
        coverage.attributes['branch-rate'] = ((result&.covered_branches || 0) / (result&.total_branches || 1)).to_s
        coverage.attributes['branches-covered'] = (result&.covered_branches || 0).to_s
        coverage.attributes['branches-valid'] = ((result&.covered_branches || 0) + (result&.missed_branches || 0)).to_s
        # coverage.attributes['branches-valid'] = (result&.total_branches || 0).to_s
        coverage.attributes['complexity'] = '0'
        coverage.attributes['version'] = '0'
        coverage.attributes['timestamp'] = Time.now.to_i.to_s
      end

      def set_package_attributes(package, name, result)
        package.attributes['name'] = name
        package.attributes['line-rate'] = (result.covered_percent/100).round(2).to_s
        package.attributes['branch-rate'] = ((result&.branch_covered_percent || 0)/100).round(2).to_s
        package.attributes['complexity'] = '0'
      end

      def set_class_attributes(class_, file)
        filename = file.filename
        path = filename[SimpleCov.root.length+1..-1]
        class_.attributes['name'] = File.basename(filename, '.*')
        class_.attributes['filename'] = path
        class_.attributes['line-rate'] = (file.covered_percent/100).round(2).to_s
        class_.attributes['branch-rate'] = ((file&.branches_coverage_percent || 0)/100).round(2).to_s
        class_.attributes['complexity'] = '0'
      end

      def set_line_attributes(line, file_line)
        line.attributes['number'] = file_line.line_number.to_s
        line.attributes['branch'] = 'false'
        line.attributes['hits'] = file_line.coverage.to_s
      end

      # @see https://github.com/cobertura/cobertura/wiki/Line-Coverage-Explained
      # @see https://github.com/leobalter/testing-examples/blob/master/solutions/3/report/cobertura-coverage.xml
      # @see https://gist.githubusercontent.com/apetro/fcfffb8c4cdab2c1061d/raw/e71c66321b12571b11d1ca37b531432c0010ee0f/coverage.xml
      def set_branch_attributes(branch, file_branch)
        branch.attributes['number'] = file_branch.start_line.to_s
        branch.attributes['branch'] = 'true'
        branch.attributes['hits'] = file_branch.coverage.to_s
        # branch.attributes['condition-coverage'] = "50% (1/2)"

        # branch.attributes['start_line'] = file_branch.start_line.to_s
        # branch.attributes['end_line'] = file_branch.end_line.to_s
        # branch.attributes['coverage'] = file_branch.coverage.to_s
        # branch.attributes['inline'] = file_branch.inline.to_s
        # branch.attributes['type'] = file_branch.type.to_s
      end

      def set_xml_head(lines=[])
        lines << "<?xml version=\"1.0\"?>"
        lines << "<!DOCTYPE coverage SYSTEM \"#{DTD_URL}\">"
        lines << "<!-- Generated by simplecov-cobertura version #{VERSION} (https://github.com/dashingrocket/simplecov-cobertura) -->"
        lines.join("\n")
      end
    end
  end
end
