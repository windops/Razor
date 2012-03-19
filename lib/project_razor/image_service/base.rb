# EMC Confidential Information, protected under EMC Bilateral Non-Disclosure Agreement.
# Copyright © 2012 EMC Corporation, All Rights Reserved

require "fileutils"
require "digest/sha2"

module ProjectRazor
  module ImageService
    # Base image abstract
    class Base < ProjectRazor::Object

      attr_accessor :filename
      attr_accessor :description
      attr_accessor :size
      attr_accessor :verification_hash
      attr_accessor :path_prefix

      def initialize(hash)
        super()
        @path_prefix = "base"
        from_hash(hash) unless hash == nil
      end


      # Used to add an image to the service
      # Within each child class the methods are overridden for that child type
      def add(src_image_path, image_svc_path)
        @image_svc_path = image_svc_path + "/" + @path_prefix

        begin
          # Get full path
          fullpath = File.expand_path(src_image_path)
          # Get filename
          @filename = File.basename(fullpath)

          puts "fullpath: #{fullpath}".red
          logger.debug "fullpath: #{fullpath}"
          puts "filename: #{@filename}".red
          logger.debug "filename: #{@filename}"
          puts "mount path: #{mount_path}".red
          logger.debug "mount path: #{mount_path}"


          # Make sure file exists
          return cleanup([false,"File does not exist"]) unless File.exist?(fullpath)

          # Make sure it has an .iso extension
          return cleanup([false,"File is not an ISO"]) if @filename[-4..-1] != ".iso"



          # Confirm a mount doesn't already exist
          if is_mounted?(fullpath)
            puts "already mounted"
          else
            puts "not mounted already"
            unless mount(fullpath)
              logger.error "Could not mount #{fullpath} on #{mount_path}"
              return cleanup([false,"Could not mount"])
            end
          end

          # Determine if there is an existing image path for iso
          if is_image_path?
            ## Remove if there is
            remove_dir_completely(image_path)
          end

          ## Create image path
          unless create_image_path
            logger.error "Cannot create image path: #{image_path}"
            return cleanup([false, "Cannot create image path: #{image_path}"])
          end

          # Attempt to copy from mount path to image path
          unless copy_to_image_path
            logger.error "Cannot copy to image path: #{image_path}"
            return cleanup([false, "Cannot copy to image path: #{image_path}"])
          end

          # Verify diff between mount / image paths
          # For speed/flexibility reasons we just verify all files exists and not their contents
          @verification_hash = get_dir_hash(image_path)
          unless get_dir_hash(mount_path) == @verification_hash
            logger.error "Image copy failed verification: #{image_path}"
            return cleanup([false, "Image copy failed verification: #{image_path}"])
          end

        rescue => e
          logger.error e.message
          return cleanup([false,e.message])
        end

        cleanup([true ,""])
      end

      # Used to remove an image to the service
      # Within each child class the methods are overridden for that child type
      def remove

      end

      # Used to verify an image within the filesystem (local/remote/possible Glance)
      # Within each child class the methods are overridden for that child type
      def verify

      end

      def image_path
        @image_svc_path + "/" + @uuid
      end

      def is_mounted?(src_image_path)
        mounts.each do
        |mount|
          return true if mount[0] == src_image_path && mount[1] == mount_path
        end
        false
      end

      def mount(src_image_path)
        FileUtils.mkpath(mount_path) unless Dir.exist?(mount_path)

        `mount -o loop #{src_image_path} #{mount_path} 2> /dev/null`
        if $? == 0
          logger.debug "mounted: #{src_image_path} on #{mount_path}"
          true
        else
          logger.debug "could not mount: #{src_image_path} on #{mount_path}"
          false
        end
      end

      def umount
        `umount #{mount_path} 2> /dev/null`
        if $? == 0
          logger.debug "unmounted: #{mount_path}"
          true
        else
          logger.debug "could not unmount: #{mount_path}"
          false
        end
      end

      def copy_iso_to_image

      end

      def verify_copy

      end

      def mounts
        `mount`.split("\n").map! {|x| x.split("on")}.map! {|x| [x[0],x[1].split(" ")[0]]}
      end

      def cleanup(ret)
        umount
        remove_dir_completely(mount_path)
        remove_dir_completely(image_path) if !ret[0]
        logger.error "Error: #{ret[1]}" if !ret[0]
        ret
      end

      def mount_path
        "#{$temp_path}/#{@uuid}"
      end

      def is_image_path?
        Dir.exist?(image_path)
      end

      def create_image_path
        FileUtils.mkpath(image_path)
      end

      def remove_dir_completely(path)
        if Dir.exist?(path)
          FileUtils.rm_r(path, :force => true)
        else
          true
        end
      end

      def copy_to_image_path
        FileUtils.cp_r(mount_path, image_path)
      end

      def get_dir_hash(dir)
        Digest::SHA2.hexdigest(Dir.glob("#{dir}/**/*").map {|x| x.sub("#{dir}/","")}.join("\n"))
      end

    end
  end
end