# Copyright 2014-present Greg Hurrell. All rights reserved.
# Licensed under the terms of the BSD 2-clause license.

require 'open3'

module CommandT
  class Scanner
    class FileScanner
      # A FileScanner which shells out to the `rg` executable in order to scan.
      class RipgrepFileScanner < FileScanner
        include PathUtilities

        def paths!
          # temporarily set field separator to NUL byte; this setting is
          # respected by both `each_line` and `chomp!` below, and makes it easier
          # to parse the output of `find -print0`
          separator = $/
          $/ = "\x00"

          unless @scan_dot_directories
            dot_directory_filter = [
              '--glob', "!#{@path}/.*/*",   # top-level dot dir
              '--glob', "!#{@path}/*/.*/*"  # lower-level dot dir
            ]
          end

          paths = []
          Open3.popen3(*([
            'rg', '--follow',               # follow symlinks
            @path,                          # anchor search here
            '--maxdepth', @max_depth.to_s,  # limit depth of DFS
            '--files',                      # only show files (not dirs etc)
            '--hidden',                     # include hidden files and directories
            dot_directory_filter,           # possibly skip out dot directories
            '--null'                        # NUL-terminate results
          ].flatten.compact)) do |stdin, stdout, stderr|
            counter = 1
            next_progress = progress_reporter.update(counter)
            stdout.each_line do |line|
              next if path_excluded?(line.chomp!)
              paths << line[@prefix_len..-1]
              next_progress = progress_reporter.update(counter) if counter == next_progress
              if (counter += 1) > @max_files
                show_max_files_warning
                break
              end
            end
          end
          paths
        ensure
          $/ = separator
        end
      end
    end
  end
end
