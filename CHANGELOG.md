# Changelog

## [Unreleased]

### Added
- Added parallel tempering support through `ParallelTemperingMC` (#14).

### Changed

- changed AbstractMC interface signature `Carlo.register_evaluables(::Type{YourMC}, ::Evaluator, ::AbstractDict)` → `Carlo.register_evaluables(::Type{YourMC}, ::AbstractEvaluator, params::AbstractDict)`. This is backwards compatible, but if you want to use parallel tempering, you have to use `::AbstractEvaluatior` or `::Any`.

### Fixed

- handling of Matrix or higher rank observables by ResultTools
