# Copy… TODO delete
const MT_CACHE_F = 501 << 1 # number of Float64 in the cache
const MT_CACHE_I = 501 << 4 # number of bytes in the UInt128 cache

@assert dsfmt_get_min_array_size() <= MT_CACHE_F

mutable struct MersenneTwister <: AbstractRNG
    seed::Vector{UInt32}
    state::DSFMT_state
    vals::Vector{Float64}
    ints::Vector{UInt128}
    idxF::Int
    idxI::Int

    # counters for show
    adv::Int64          # state of advance at the DSFMT_state level
    adv_jump::BigInt    # number of skipped Float64 values via randjump
    adv_vals::Int64     # state of advance when vals is filled-up
    adv_ints::Int64     # state of advance when ints is filled-up

    function MersenneTwister(seed, state, vals, ints, idxF, idxI,
                             adv, adv_jump, adv_vals, adv_ints)
        length(vals) == MT_CACHE_F && 0 <= idxF <= MT_CACHE_F ||
            throw(DomainError((length(vals), idxF),
                      "`length(vals)` and `idxF` must be consistent with $MT_CACHE_F"))
        length(ints) == MT_CACHE_I >> 4 && 0 <= idxI <= MT_CACHE_I ||
            throw(DomainError((length(ints), idxI),
                      "`length(ints)` and `idxI` must be consistent with $MT_CACHE_I"))
        new(seed, state, vals, ints, idxF, idxI,
            adv, adv_jump, adv_vals, adv_ints)
    end
end

MersenneTwister(seed::Vector{UInt32}, state::DSFMT_state) =
    MersenneTwister(seed, state,
                    Vector{Float64}(undef, MT_CACHE_F),
                    Vector{UInt128}(undef, MT_CACHE_I >> 4),
                    MT_CACHE_F, 0, 0, 0, -1, -1)

"""
    MersenneTwister(seed)
    MersenneTwister()
Create a `MersenneTwister` RNG object. Different RNG objects can have
their own seeds, which may be useful for generating different streams
of random numbers.
The `seed` may be a non-negative integer or a vector of
`UInt32` integers. If no seed is provided, a randomly generated one
is created (using entropy from the system).
See the [`seed!`](@ref) function for reseeding an already existing
`MersenneTwister` object.
# Examples
```jldoctest
julia> rng = MersenneTwister(1234);
julia> x1 = rand(rng, 2)
2-element Vector{Float64}:
 0.5908446386657102
 0.7667970365022592
julia> rng = MersenneTwister(1234);
julia> x2 = rand(rng, 2)
2-element Vector{Float64}:
 0.5908446386657102
 0.7667970365022592
julia> x1 == x2
true
```
"""
MersenneTwister(seed=nothing) =
    seed!(MersenneTwister(Vector{UInt32}(), DSFMT_state()), seed)


function copy!(dst::MersenneTwister, src::MersenneTwister)
    copyto!(resize!(dst.seed, length(src.seed)), src.seed)
    copy!(dst.state, src.state)
    copyto!(dst.vals, src.vals)
    copyto!(dst.ints, src.ints)
    dst.idxF = src.idxF
    dst.idxI = src.idxI
    dst.adv = src.adv
    dst.adv_jump = src.adv_jump
    dst.adv_vals = src.adv_vals
    dst.adv_ints = src.adv_ints
    dst
end

copy(src::MersenneTwister) =
    MersenneTwister(copy(src.seed), copy(src.state), copy(src.vals), copy(src.ints),
                    src.idxF, src.idxI, src.adv, src.adv_jump, src.adv_vals, src.adv_ints)

==(r1::MersenneTwister, r2::MersenneTwister) =
    r1.seed == r2.seed && r1.state == r2.state &&
    isequal(r1.vals, r2.vals) &&
    isequal(r1.ints, r2.ints) &&
    r1.idxF == r2.idxF && r1.idxI == r2.idxI

hash(r::MersenneTwister, h::UInt) =
    foldr(hash, (r.seed, r.state, r.vals, r.ints, r.idxF, r.idxI); init=h)

function show(io::IO, rng::MersenneTwister)
    # seed
    seed = from_seed(rng.seed)
    seed_str = seed <= typemax(Int) ? string(seed) : "0x" * string(seed, base=16) # DWIM
    if rng.adv_jump == 0 && rng.adv == 0
        return print(io, MersenneTwister, "(", seed_str, ")")
    end
    print(io, MersenneTwister, "(", seed_str, ", (")
    # state
    adv = Integer[rng.adv_jump, rng.adv]
    if rng.adv_vals != -1 || rng.adv_ints != -1
        if rng.adv_vals == -1
            @assert rng.idxF == MT_CACHE_F
            push!(adv, 0, 0) # "(0, 0)" is nicer on the eyes than (-1, 1002)
        else
            push!(adv, rng.adv_vals, rng.idxF)
        end
    end
    if rng.adv_ints != -1
        idxI = (length(rng.ints)*16 - rng.idxI) / 8 # 8 represents one Int64
        idxI = Int(idxI) # idxI should always be an integer when using public APIs
        push!(adv, rng.adv_ints, idxI)
    end
    join(io, adv, ", ")
    print(io, "))")
end


