module Paperclip
  module Storage
    module S3
      def self.extended base
        begin
          require 'aws/s3'
        rescue LoadError => e
          e.message << " (You may need to install the aws-s3 gem)"
          raise e
        end

        base.instance_eval do
          @s3_credentials = parse_credentials(@options[:s3_credentials])
          @bucket         = @options[:bucket]         || @s3_credentials[:bucket]
          @bucket_alt     = @options[:bucket_alt]     || @s3_credentials[:bucket_alt]
          @testing        = @options[:testing]        || @s3_credentials[:testing]
          @bucket         = @bucket.call(self) if @bucket.is_a?(Proc)
          @s3_options     = @options[:s3_options]     || {}
          @s3_permissions = @options[:s3_permissions] || :public_read
          @s3_protocol    = @options[:s3_protocol]    || (@s3_permissions == :public_read ? 'http' : 'https')
          @s3_headers     = @options[:s3_headers]     || {}
          @s3_host_alias  = @options[:s3_host_alias]
          @url            = ":s3_path_url" unless @url.to_s.match(/^:s3.*url$/)
          AWS::S3::Base.establish_connection!( @s3_options.merge(
                                                                 :access_key_id => @s3_credentials[:access_key_id],
                                                                 :secret_access_key => @s3_credentials[:secret_access_key]
                                                                 ))
        end
        Paperclip.interpolates(:s3_alias_url) do |attachment, style|
          "#{attachment.s3_protocol}://#{attachment.s3_host_alias}/#{attachment.path(style).gsub(%r{^/}, "")}"
        end

        Paperclip.interpolates(:s3_path_url) do |attachment, style|
          # if @testing and alt_exists?(style)
          if !attachment.testing or !attachment.alt_exists?(style)
            "#{attachment.s3_protocol}://s3.amazonaws.com/#{attachment.bucket_name}/#{attachment.path(style).gsub(%r{^/}, "")}"
          else
            "#{attachment.s3_protocol}://s3.amazonaws.com/#{attachment.alt_bucket_name}/#{attachment.path(style).gsub(%r{^/}, "")}"
          end
        end

        Paperclip.interpolates(:s3_domain_url) do |attachment, style|
          if !attachment.testing or !attachment.alt_exists?(style)
            "#{attachment.s3_protocol}://#{attachment.bucket_name}.s3.amazonaws.com/#{attachment.path(style).gsub(%r{^/}, "")}"
          else
            "#{attachment.s3_protocol}://#{attachment.alt_bucket_name}.s3.amazonaws.com/#{attachment.path(style).gsub(%r{^/}, "")}"
          end
        end
      end

      def alt_bucket_name
        @bucket_alt
      end

      def testing
        @testing
      end

      def alt_exists?(style = default_style)
        if original_filename
          AWS::S3::S3Object.exists?(path(style), alt_bucket_name)
        else
          false
        end
      end

      # Returns representation of the data of the file assigned to the given
      # style, in the format most representative of the current storage.
      def to_file style = default_style
        return @queued_for_write[style] if @queued_for_write[style]
        file = Tempfile.new(path(style))
        if !testing or !alt_exists?(style)
          file.write(AWS::S3::S3Object.value(path(style), bucket_name))
        else
          file.write(AWS::S3::S3Object.value(path(style), alt_bucket_name))
        end
        file.rewind
        return file
      end

    end
  end
end
