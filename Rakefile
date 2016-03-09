require 'yaml'
require 'json'
require 'fileutils'
require 'tmpdir'

namespace :jobs do
  desc "Update job specs"
  task :update_spec do
    include JobSpecs
    update_job_specs
  end
end

namespace :images do
  desc "Export docker images locally; in Concourse get them via resources"
  task :pull, [:image] do |_, args|
    include ImageConfig
    images(args[:image]).each do |image|
      sh "docker pull #{image.name}" if ENV["DOCKER_PULL"]
      FileUtils.mkdir_p(source_image_dir(File.dirname(image.tar)))
      sh "docker save #{image.name} > #{source_image_dir(image.tar)}"
    end
  end

  desc "Package exported images"
  task :package do |_, args|
    include DockerImagePackaging
    include ImageConfig

    # blobs might be in either/or blobs/docker_layers/* or in config/blobs.yml
    downloaded_layers = Dir["blobs/docker_layers/*"].map {|b| File.basename(b) }
    config_layers = YAML.load_file("config/blobs.yml").keys.
      keep_if {|b| b =~ /^docker_layers/}.
      map {|b| File.basename(b) }
    existing_layers = (downloaded_layers + config_layers).uniq

    required_layers = []
    images.each do |image|
      Dir.mktmpdir do |dir|
        required_blobs = repackage_image_blobs(source_image_dir(image.tar), dir, image.name)

        required_blobs.each do |b|
          unless existing_layers.include?(b.target)
            sh "bosh add blob #{b.blob_target(dir)} #{b.prefix}"
          end
          required_layers << b.target
        end
        create_package(image.package, required_blobs.map(&:package_spec_path), image.name)
      end
    end
    puts "Removing unused blobs:"
    remove_layers = existing_layers - required_layers

    blobs = YAML.load_file("config/blobs.yml")
    remove_layers.each do |layer_file|
      puts "Removing #{layer_file}..."
      FileUtils.rm_rf(File.join("blobs/docker_layers", layer_file))
      blobs.delete(File.join("docker_layers", layer_file))
    end
    IO.write("config/blobs.yml", blobs.to_yaml)
  end

  task :cleanout do
    FileUtils.rm_rf("blobs/docker_images")
    file = "config/blobs.yml"
    blobs = YAML.load_file(file)
    blobs = blobs.keep_if { |blob, _| !(blob =~ /^(docker_images)/) }
    IO.write(file, blobs.to_yaml)
  end
end

module CommonDirs
  def repo_dir
    File.expand_path("../", __FILE__)
  end

  def source_image_dir(relative_path = "")
    image_base_dir = ENV['IMAGE_BASE_DIR'] || File.join(repo_dir, 'tmp')
    File.join(image_base_dir, relative_path)
  end

  def packages_dir(path = "")
    File.join(repo_dir, 'packages', path)
  end

  def jobs_dir(path = "")
    File.join(repo_dir, 'jobs', path)
  end
end

module ImageConfig
  include CommonDirs

  def images(image = nil)
    @images ||= begin
      images = YAML.load_file(File.expand_path('../images.yml', __FILE__))
      images.keep_if { |i| i['image'].to_s == image } if image
      images.map! { |i| Image.new(i["image"], i["tag"], i["job"]) }
    end
  end

  class Image
    attr_reader :job

    def initialize(name, tag, job)
      @name = name
      @tag = tag
      @job = job
    end

    def name
      @name + ":" + @tag
    end

    def package
      name.gsub(/[\/\-\:\.]/, '_') + "_image"
    end

    # file that matches output from concourse docker-image-resource
    def tar
      "#{package}/image"
    end
  end
end

module JobSpecs
  include CommonDirs
  include ImageConfig

  def packages_for_job(job)
    images.select { |i| i.job == job }.map(&:package)
  end

  def update_job_specs
    jobs = images.collect(&:job)
    jobs.each do |job|
      file = "jobs/#{job}/spec"
      spec = YAML.load_file(file)
      spec["packages"] = packages_for_job(job)
      IO.write(file, spec.to_yaml)
      puts "Updated: #{file}"
    end
  end
end
module DockerImagePackaging
  include CommonDirs

  class Blob
    attr_reader :source, :target_dir, :prefix

    # target_dir is a folder akin to output from concourse/docker-image-resource
    # with an +image+ file that is the `docker save` tgz file (see +source_blob+)
    def initialize(source, target_name, prefix)
      @source = source
      @target_name = target_name
      @prefix = prefix
    end

    def target
      "#{@target_name}.tgz"
    end

    def blob_target(dir)
      File.join(dir, target)
    end

    def package_spec_path
      "#{@prefix}/#{target}"
    end
  end

  def repackage_image_blobs(image_tar, tmp_layers_dir, image_name)
    Dir.chdir(tmp_layers_dir) do
      sh "tar -xf #{image_tar}"
      sh "tree"

      # Add tagging data so the correct tag will be applied on import
      manifest = JSON.parse(File.read("manifest.json"))
      manifest[0]["RepoTags"] = [image_name]
      File.write("manifest.json", JSON.dump(manifest))

      # Blob.new(source, target_name, prefix)
      blobs = Dir.glob("*/").map! do |d|
               Blob.new(d.chop, d.chop, 'docker_layers')
      end
      Dir.glob("*.json") do |json|
        next if json =~ /manifest.json$/
        blobs << Blob.new(json, File.basename(json), 'docker_images')
      end
      blobs << Blob.new('manifest.json', File.basename(File.dirname(image_tar)), 'docker_images')

      package_blobs(blobs)
    end
  end

  def package_blobs(blobs)
    blobs.each { |b| sh "tar -zcf #{b.target} #{b.source}" }
  end

  def create_package(name, files, docker_tag)
    package_dir = File.expand_path("../packages/#{name}", __FILE__)
    FileUtils.mkdir_p package_dir
    src_meta_dir = File.expand_path("../src/#{name}", __FILE__)
    FileUtils.mkdir_p src_meta_dir
    puts "Src meta dir is #{src_meta_dir}"
    meta_file = File.join(name, 'docker_meta.txt')
    files.push(meta_file)
    spec = { "name" => name, "files" => files }
    IO.write(File.join(package_dir, 'spec'), spec.to_yaml)
    IO.write(File.join(src_meta_dir, 'docker_meta.txt'), docker_tag)
    IO.write(File.join(package_dir, 'packaging'), packaging_script(meta_file))
  end


  def packaging_script(docker_meta)
    <<-END.gsub(/^ {6}/, '')
      set -e; set -u

      cp -a #{docker_meta} $BOSH_INSTALL_TARGET
      mkdir bits
      cd bits
      for layer in ../docker_layers/*.tgz; do tar -xf "$layer"; done
      for layer in ../docker_images/*.tgz; do tar -xf "$layer"; done
      tar -zcf image.tgz ./*
      cp -a image.tgz $BOSH_INSTALL_TARGET
    END
  end
end
