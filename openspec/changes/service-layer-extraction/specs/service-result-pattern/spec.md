## ADDED Requirements

### Requirement: ServiceResult return type

All service objects SHALL return a `ServiceResult` object with `success?`, `payload`, and `errors` methods.

#### Scenario: Successful service call

- **WHEN** a service completes successfully
- **THEN** it SHALL return a `ServiceResult` where `success?` is true and `payload` contains the result data

#### Scenario: Failed service call

- **WHEN** a service encounters a validation or business logic error
- **THEN** it SHALL return a `ServiceResult` where `success?` is false and `errors` contains an array of error messages

### Requirement: ApplicationService base class

All service objects SHALL inherit from `ApplicationService` with a `.call` class method that instantiates and invokes the service.

#### Scenario: Calling a service

- **WHEN** a consumer calls `Documents::CreateService.call(params)`
- **THEN** the service SHALL instantiate, execute, and return a `ServiceResult`
