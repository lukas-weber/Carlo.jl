# ArgParse.jl leads to slow startups and has many features we do not need.
# This little custom parser covers just what we need. Feel free to hack it for your own project!

module TinyArgParse

struct Option
    long::String
    short::Union{String,Nothing}
    description::String
end

help() = Option("help", "h", "Show this message")

struct Command
    name::String
    short::Union{String,Nothing}
    description::String
    options::Vector{Option}
end

struct Error
    name::String
    type::String
    help::String
end

function Error(name::AbstractString, type::AbstractString, help_args::Tuple)
    io = IOBuffer()
    print_help(io, help_args...)
    return Error(name, type, String(take!(io)))
end

Base.showerror(io::IO, e::Error) = print(io, "Unknown $(e.type) '$(e.name)'!\n$(e.help)")

"""
    parse(options::AbstractVector{Option}, args::AbstractVector{String}) -> Tuple{Dict{String,Any}, Vector{String}}

Parse `args` according to the `options`. Will stop at the first argument that does not start with `-` and return a tuple of a dictionary
that maps long key names to true (parameters are not yet supported) and a vector of leftover args. Unknown arguments will throw an TinyArgParse.Error.
"""
function parse(options::AbstractVector{Option}, args::AbstractVector{String})
    longs = Set(s.long for s in options)
    short2long =
        Dict{Char,String}(only(s.short) => s.long for s in options if !isnothing(s.short))
    parsed = Dict{String,Any}() # for now, arguments do not take parameters, but maybe later

    leftover_args = String[]
    for (i, arg) in enumerate(args)
        if startswith(arg, "--")
            argname = arg[3:end]
            argname in longs || throw(Error(arg, "argument", (options,)))
            parsed[argname] = true
        elseif startswith(arg, "-")
            for argname in arg[2:end]
                haskey(short2long, argname) ||
                    throw(Error("-" * argname, "argument", (options,)))
                parsed[short2long[argname]] = true
            end
        else
            leftover_args = args[i:end]
            break
        end
    end

    return parsed, leftover_args
end
"""
    parse(commands::AbstractVector{Command}, general_options::AbstractVector{Option}, args::AbstractVector{String})

Parse `args` for a command-style CLI:

    program.jl [GENERAL_OPTIONS] <COMMAND> [SPECIFIC_OPTIONS]

The function returns a tuple `cmd, general, specific`, consisting of the name `cmd` of the command and the `general` and `specific` option dictionaries.
"""
function parse(
    commands::AbstractVector{Command},
    general_options::AbstractVector{Option},
    args::AbstractVector{String},
)
    general, leftover_args = try
        parse(general_options, args)
    catch e
        if e isa Error
            e = Error(e.name, e.type, (commands, general_options))
        end
        rethrow(e)
    end

    short2long = Dict{String,Int}(
        s.short => i for (i, s) in enumerate(commands) if !isnothing(s.short)
    )

    if isempty(leftover_args)
        return nothing, general, nothing
    end

    cmd_idx = findfirst(c -> c.name == leftover_args[1], commands)
    if isnothing(cmd_idx)
        if haskey(short2long, leftover_args[1])
            cmd_idx = short2long[leftover_args[1]]
        else
            throw(Error(leftover_args[1], "command", (commands, general_options)))
        end
    end

    command = commands[cmd_idx]

    specific, empty_args = try
        parse(command.options, leftover_args[2:end])
    catch e
        if e isa Error
            e = Error(e.name, e.type, (command,))
        end
        rethrow(e)
    end
    if !isempty(empty_args)
        throw(Error(empty_args[1], "extra parameter", (command,)))
    end

    return command.name, general, specific
end

function handle_help(cmd::AbstractString, general::AbstractDict, specific::AbstractDict)
    if haskey(general, "help") || (!isnothing(specific) && haskey(specific, "help"))
        if isnothing(cmd)
            AP.print_help(stdout, commands, general_args)
        else
            command = commands[findfirst(c -> c.name == cmd, commands)]
            AP.print_help(stdout, command)
        end
        return true
    end
    return false
end

function print_help(
    io::IO,
    command::AbstractVector{Command},
    general_options::AbstractVector{Option};
    program_name = PROGRAM_FILE,
)
    println(io, "Usage: $program_name [OPTIONS] {$(join((c.name for c in command), "|"))}")
    args_width = maximum(s -> length(s.long), general_options)
    cmd_width = max(args_width + 6, maximum(c -> length(c.name), command))

    cmd_help = join(map(command) do cmd
        shortcut = isnothing(cmd.short) ? "" : " (alias: $(cmd.short))"
        return "  $(rpad(cmd.name, cmd_width))  $(cmd.description)$shortcut"
    end, "\n")
    println(io, "\nCommands:\n$cmd_help\n")

    print_help(io, general_options)
end

function print_help(io::IO, command::Command; program_name = PROGRAM_FILE)
    println(io, "Usage: $program_name $(command.name) [OPTIONS]")
    println(io, "\n$(command.description)\n")
    print_help(io, command.options)
end

function print_help(io::IO, options::AbstractVector{Option})
    args_width = maximum(s -> length(s.long), options)
    args_help = join(
        map(options) do arg
            short = isnothing(arg.short) ? "   " : "-$(arg.short),"
            return "  $short --$(rpad(arg.long, args_width))  $(arg.description)"
        end,
        "\n",
    )

    println(io, "Options:\n$args_help")
end

end
