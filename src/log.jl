using Logging
using Dates

const date_format = "yyyy-mm-dd HH:MM:SS"

function log_formatter(level::LogLevel, _module, group, id, file, line)
    (color, prefix, suffix) = Logging.default_metafmt(level, _module, group, id, file, line)

    return color, "$(prefix) $(Dates.format(now(), date_format))", suffix
end

global_logger(ConsoleLogger(meta_formatter = log_formatter))
