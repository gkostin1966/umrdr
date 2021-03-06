#require 'rspec/core'
#require 'rspec/core/rake_task'
require 'open-uri'

desc 'Extract files from fedora 01'
task :extract_files_01 => :environment do
  Umrdr::ExtractFilesFromFedora01.run
end

module Umrdr

  # TODO: parametrize the work id
  # TODO: parametrize the target directory
  class ExtractFilesFromFedora01
    def self.run
      id = 'jh343s28d'
      id = 'wp988j816'
      puts "id=#{id}"
      w = GenericWork.find id
      tmp = "/deepbluedata-prep"
      Dir.mkdir( tmp ) unless File.exists?( tmp )
      tmp = tmp + "/fedora-extract"
      Dir.mkdir( tmp ) unless File.exists?( tmp )
      tmp = tmp + "/" + w.id
      puts "tmp=#{tmp}"
      Dir.mkdir( tmp ) unless File.exists?( tmp )
      files_extracted = Hash.new
      w.file_sets.each do |file_set|
        begin
          file = file_set.files[0]
          target_file_name = file_set.label
          if files_extracted.has_key? target_file_name
            dup_count = 1
            base_ext = File.extname target_file_name
            base_target_file_name = File.basename target_file_name, base_ext
            target_file_name = base_target_file_name + "_" + dup_count.to_s.rjust( 3, '0' ) + base_ext
            while files_extracted.has_key? target_file_name
              dup_count += 1
              target_file_name = base_target_file_name + "_" + dup_count.to_s.rjust( 3, '0' ) + base_ext
            end
          end
          files_extracted.store( target_file_name, true )
          target_file = tmp + "/" + target_file_name
          source_uri = file.uri.value
          puts "copy #{target_file} << #{source_uri}"
          bytes_copied = open(source_uri) { |io| IO.copy_stream(io, target_file) }
          puts "bytes copied #{bytes_copied}"
        rescue Exception => e
          #STDERR.puts "UpdateWorksTotalFileSizes #{e.class}: #{e.message}"
          puts "Exception: #{e.class}: #{e.message}"
        end
      end
    end

  end

end
