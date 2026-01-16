Feature: Model Management
  As a machine learning practitioner
  I want to create and manage ML models
  So that I can train and deploy them

  Background:
    Given the MacML app is running
    And I am on the Models view

  Scenario: Create a new model
    When I click "New Model"
    Then a model creation sheet should appear
    And I should see framework selection options

  Scenario: Create model with valid details
    When I click "New Model"
    And I enter "TestModel" as the model name
    And I select "MLX" as the framework
    And I click "Create"
    Then the model should be created
    And I should see "TestModel" in the model list

  Scenario: Cancel model creation
    When I click "New Model"
    And I click "Cancel"
    Then the sheet should close
    And no model should be created

  Scenario: Delete a model
    Given a model "TestModel" exists
    When I select "TestModel" in the model list
    And I click "Delete"
    And I confirm the deletion
    Then "TestModel" should be removed from the list

  Scenario: View model details
    Given a model "MyModel" exists
    When I click on "MyModel" in the model list
    Then I should see the model details panel
    And I should see the model's accuracy
    And I should see the model's creation date
