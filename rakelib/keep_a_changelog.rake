
# FIXME: only needed with this weird setup
$:.push *(Dir[File.expand_path('.gems/gems/*/lib')])


class KeepAChangelogTools

  NEW_UNRELEASED_MARKUP=<<~TEXT
    ## [Unreleased]

    ### Added

    ### Changed

    ### Fixed

    ### Removed
  TEXT

  def initialize( file='CHANGELOG.md' )
    @file = file
  end

  #
  #
  # Supported cases:
  # - [x] Common: existing `## [Unreleased]` header + reflinks with `/compare/`
  #   - [x] Change [Unreleased] link to `[<tag_name>]`
  #   - [x] Add `[<tag_name>]: ` reflink with `/compare/<previous_tag>...<tag_name>`
  #   - [x] Add new `[Unreleased]:` reflink with compare starting from `<tag_name>`
  # - [ ] First release
  # - [ ] Missing Unreleased reflink
  #
  # Additional cases:
  # - [ ] `<tag_name>` reflink already released (fail w/error)
  def release(tag_name, include_todays_date)
    lines = File.open(@file,'r').readlines

    # Supported case: Common
    header_idx = lines.index{|x| x =~ /^#+ \[Unreleased\]/ }
    fail "ERROR: No [Unreleased] header to release!" unless header_idx
    lines[header_idx].sub!(/Unreleased/, tag_name)

    if include_todays_date
      require 'date'
      lines[header_idx].sub!(/$/, " - #{DateTime.now.strftime('%Y-%m-%d')}")
    end

    reflink_idx = lines.index{|x| x =~ %r{^\[Unreleased\]: .*/compare/.*\.\.\.} }
    if reflink_idx
      unrel_reflink_txt = lines[reflink_idx].dup
      lines.delete_at(reflink_idx)
      lines.insert( reflink_idx, unrel_reflink_txt.sub(%r{[^/]+...HEAD$}, "#{tag_name}...HEAD"))
      puts "Updated `[Unreleased]` reflink to start tracking from `[#{tag_name}]`"
      lines.insert( reflink_idx, unrel_reflink_txt.sub('Unreleased',tag_name).sub(/HEAD$/, tag_name))
      puts "Changed `[Unreleased]` section + reflink to `[#{tag_name}]`"
      lines.insert(header_idx, "\n<!--\n" + NEW_UNRELEASED_MARKUP + "-->\n\n")
    end
    File.open(@file,'w'){|f| f.puts lines.join }
    puts "Rewrote #{@file} with new content"
  end

end


namespace 'keep-a-changelog' do

  desc <<~DESC
    Release a new Keep-a-changelog version of the CHANGELOG

      :tag_name       => name of git tag for relese
      :create_git_tag => (default: 'no') When 'yes', also create the git tag
                         specified in `:tag_name`
      :timestamp      => (default: 'yes') When 'yes', append today's date to
                         the release header in `YYYY-mm-dd` format

  DESC
  task 'bump', [:tag_name, :create_git_tag, :timestamp] do |t,args|
    args.with_defaults(
      :create_git_tag => 'no',
      :timestamp      => 'yes'
    )
    create_git_tag = args[:create_git_tag] =~ /^(yes|true)$/i
    include_todays_date = args[:timestamp] !~ /^(no|false)$/i

    kacl_tools = KeepAChangelogTools.new
    kacl_tools.release(args[:tag_name], include_todays_date)
  end
end
