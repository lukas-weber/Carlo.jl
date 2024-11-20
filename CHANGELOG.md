# Changelog

## Unreleased

### Changed

- ParallelTemperingMC: measurements are now buffered, leading to less communication overhead and allowing measurements during Carlo.sweep!

## 0.2.2 - 2024-10-23

### Added
- Added parallel tempering support through `ParallelTemperingMC` (#14).

### Changed

- changed AbstractMC interface signature `Carlo.register_evaluables(::Type{YourMC}, ::Evaluator, ::AbstractDict)` → `Carlo.register_evaluables(::Type{YourMC}, ::AbstractEvaluator, params::AbstractDict)`. This is backwards compatible, but if you want to use parallel tempering, you have to use `::AbstractEvaluatior` or `::Any`.

### Fixed

- handling of Matrix or higher rank observables by ResultTools
- made `run -r` less likely to fail on distributed file systems
