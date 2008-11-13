require 'builder'
require 'zip/zip'

require 'odf/meta_stuff'

module ODF
  class Cell
    def initialize(*args)
      value = args.first || ''
      opts = args.last.instance_of?(Hash) ? args.last : {}

      @type = opts[:type] || :string
      @formula = opts[:formula]
      @value = value.to_s.strip unless value.instance_of? Hash
    end

    def xml
      elem_attrs = {'office:value-type' => @type}
      elem_attrs['office:value'] = @value unless contains_string?
      elem_attrs['table:formula'] = @formula unless @formula.nil?

      Builder::XmlMarkup.new.tag! 'table:table-cell', elem_attrs do |xml|
        xml.text(:p, @value) if contains_string?
      end
    end

    def contains_string?
      :string == @type && !@value.nil? && !@value.empty?
    end
  end

  Row = ODF::container_of :cells
  class Row
    attr_reader :number

    def initialize(number=0)
      @number = number
    end

    def xml
      Builder::XmlMarkup.new.tag! 'table:table-row' do |xml|
        xml << children_xml
      end
    end
  end

  Table = ODF::container_of :rows
  class Table
    def initialize(title)
      @title = title
      @last_row = 0
    end

    alias create_row row
    def row
      create_row(next_row) {|r| yield r if block_given?}
    end

    def xml
      Builder::XmlMarkup.new.table:table, 'table:name' => @title do |xml|
        xml << children_xml
      end
    end
  private
    def next_row
      @last_row += 1
    end
  end

  SpreadSheet = ODF::container_of :tables
  class SpreadSheet
    def self.file(ods_file_name)
      ods_file = Zip::ZipFile.open(ods_file_name, Zip::ZipFile::CREATE)
      ods_file.get_output_stream('styles.xml') {|f| f << skeleton('styles.xml')}
      ods_file.get_output_stream('META-INF/manifest.xml') {|f| f << skeleton('manifest.xml')}
      
      yield(spreadsheet = new)

      ods_file.get_output_stream('content.xml') {|f| f << spreadsheet.xml}

      ods_file.close
    end

    def xml
      b = Builder::XmlMarkup.new

      b.instruct! :xml, :version => '1.0', :encoding => 'UTF-8'
      b.tag! 'office:document-content', 'xmlns:office' => "urn:oasis:names:tc:opendocument:xmlns:office:1.0",
                                        'xmlns:table' => "urn:oasis:names:tc:opendocument:xmlns:table:1.0",
                                        'xmlns:text' => "urn:oasis:names:tc:opendocument:xmlns:text:1.0",
                                        'xmlns:oooc' => "http://openoffice.org/2004/calc",
                                        'xmlns:style' => "urn:oasis:names:tc:opendocument:xmlns:style:1.0",
                                        'xmlns:fo' => "urn:oasis:names:tc:opendocument:xmlns:xsl-fo-compatible:1.0" do
      |xml|
        xml.office:body do
          xml.office:spreadsheet do
            xml << children_xml
          end
        end
      end
    end

  private
    def self.skeleton(fname)
      File.open(File.dirname(__FILE__) + '/skeleton/' + fname).read
    end
  end
end

