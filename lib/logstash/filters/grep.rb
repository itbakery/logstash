require "logstash/filters/base"

class LogStash::Filters::Grep < LogStash::Filters::Base
  def initialize(config = {})
    super

    @config = config
  end # def initialize

  def register
    @config.each do |type, matches|
      if ! matches.is_a?(Array)
        @logger.warn("grep: #{type} misconfigured; must be an array")
        next
      end

      matches.each_index do |i|
        match = matches[i]
        if ! match.member?("match")
          @logger.warn(["grep: #{type}/#{i}: no 'match' section defined", match])
          next
        end
        match["match"].each do |field, re_str|
          re = Regexp.new(re_str)
          @config[type][i]["match"][field] = re
          @logger.debug(["grep: #{type}/#{i}/#{field}", re_str, re])
        end
      end # matches.each
    end # @config.each
  end # def register

  def filter(event)
    config = @config[event.type]
    if not config
      @logger.debug("grep: skipping type #{event.type} from #{event.source}")
      event.cancel
      return
    end

    @logger.debug(["Running grep filter", event, config])
    matched = false
    config.each do |match|
      if ! match["match"]
        @logging.debug(["Skipping match object, no match key", match])
        next
      end

      # For each match object, we have to match everything in order to
      # apply any fields/tags.
      match_count = 0
      match["match"].each do |field, re|
        next unless event[field]

        event[field].each do |value|
          next unless re.match(value)
          @logger.debug("grep matched on field #{field}")
          match_count += 1
          break
        end
      end # match["match"].each

      if match_count == match["match"].length
        matched = true
        @logger.debug("matched all fields (#{match_count})")

        if match["add_fields"]
          match["add_fields"].each do |field, value|
            event[field] ||= []
            event[field] << value
            @logger.debug("grep: adding #{value} to field #{field}")
          end
        end # if match["add_fields"]

        if match["add_tags"]
          match["add_tags"].each do |tag|
            event.tags << tag
            @logger.debug("grep: adding tag #{tag}")
          end
        end # if match["add_tags"]
      else
        @logger.debug("match block failed " \
                      "(#{match_count}/#{match["match"].length} matches)")
      end # match["match"].each
    end # config.each

    if not matched
      @logger.debug("grep: dropping event, no matches")
      event.cancel
      return
    end

    @logger.debug(["Event after grep filter", event.to_hash])
  end # def filter
end # class LogStash::Filters::Grep
