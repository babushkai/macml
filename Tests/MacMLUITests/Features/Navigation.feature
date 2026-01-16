Feature: App Navigation
  As a user
  I want to navigate between different sections of the app
  So that I can access models, datasets, and training features

  Background:
    Given the MacML app is running

  Scenario: Launch app successfully
    Then the main window should be visible
    And the sidebar should be visible

  Scenario: Navigate to Models
    When I click on "Models" in the sidebar
    Then the Models view should be displayed
    And I should see the model list

  Scenario: Navigate to Datasets
    When I click on "Datasets" in the sidebar
    Then the Datasets view should be displayed
    And I should see the dataset list

  Scenario: Navigate to Training
    When I click on "Training" in the sidebar
    Then the Training view should be displayed

  Scenario: Navigate to Inference
    When I click on "Inference" in the sidebar
    Then the Inference view should be displayed

  Scenario: Open Settings with keyboard shortcut
    When I press Command+Comma
    Then the Settings window should open
