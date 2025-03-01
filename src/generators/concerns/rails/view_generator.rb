module Tenant
  module ViewGenerator
    def generate_view(m)
      name, hsh = build_name_and_hash(m)
      (0..8).each do |view_file|
        base_path, src, target, target_name = view_paths(:view, name, view_file)
        write_template(:view, base_path, src, target, target_name, hsh)
      end
    end
  end
end 