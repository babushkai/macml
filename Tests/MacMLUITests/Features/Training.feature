Feature: Model Training
  As a machine learning practitioner
  I want to train models with my datasets
  So that I can create accurate ML models

  Background:
    Given the MacML app is running
    And a model "TestModel" exists
    And a dataset "MNIST" exists

  Scenario: Start a training run
    Given I am on the Training view
    When I select "TestModel" as the model
    And I select "MNIST" as the dataset
    And I set epochs to 10
    And I click "Start Training"
    Then a training run should start
    And I should see training progress

  Scenario: Configure training hyperparameters
    Given I am on the Training view
    When I click "New Training Run"
    Then I should see hyperparameter options
    And I should be able to set learning rate
    And I should be able to set batch size
    And I should be able to set epochs

  Scenario: Pause and resume training
    Given a training run is in progress
    When I click "Pause"
    Then the training should pause
    When I click "Resume"
    Then the training should continue

  Scenario: Cancel training
    Given a training run is in progress
    When I click "Cancel"
    And I confirm cancellation
    Then the training should stop
    And the run should be marked as cancelled

  Scenario: View training metrics
    Given a training run is in progress
    Then I should see the loss chart
    And I should see the accuracy chart
    And I should see current epoch
    And I should see estimated time remaining
