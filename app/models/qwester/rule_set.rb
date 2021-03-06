require 'array_logic'
module Qwester
  class RuleSet < ActiveRecord::Base
    if Qwester.rails_three?
      attr_accessible :title, :description, :answers, :url, :rule, :answer_ids, :link_text, :warning_id, :presentation
    end

    before_save :keep_answers_in_step_with_rule

    DEFAULT_RULE_JOIN = 'or'
    ANSWERS_LIMIT = 10

    has_and_belongs_to_many(
      :answers,  #-> {uniq},
      #:uniq => true,
      :join_table => :qwester_answers_rule_sets
    )
    accepts_nested_attributes_for :answers

    has_many(
      :questions,
      :through => :answers
    )

    validate :check_rule_is_valid
    validate :check_answers_exist_with_ids_matching_those_in_rule

    validates :title, :presence => true
    validates :url, :presence => {:unless => :presentation?}


    def self.matching(answers)
      all.select{|rule_set| rule_set.match(answers)}
    end

    def match(answers_to_check = nil)
      return unless answers_to_check and !answers_to_check.empty?
      generate_default_rule && save
      logic.match(answers_to_check)
    end

    def logic
      @logic || get_logic
    end

    def matching_answer_sets
      @matching_answer_sets ||= logic.matching_combinations
    end

    def blocking_answer_sets
      @blocking_answer_set ||= logic.blocking_combinations
    end

    def default_rule
      answers.collect(&:rule_label).join(" #{DEFAULT_RULE_JOIN} ")
    end

    private
    def get_logic
      @logic = ArrayLogic::Rule.new rule
    end

    def generate_default_rule
      if (!self.rule or self.rule.empty?) and answers.length > 0
        self.rule = default_rule
      end
    end

    def keep_answers_in_step_with_rule
      generate_default_rule
      self.answers = get_logic.object_ids_used.collect{|id| Answer.find(id)} # need to use get_logic rather than caching logic
    end

    def check_rule_is_valid
      if rule?
        begin
        logic.send :check_rule
        rescue => e
          errors.add(:rule, "error: #{e.message}")
        end
      end
    end

    def answer_ids_in_rule
      rule? ? logic.object_ids_used : []
    end

    def answers_ids_in_database_also_found_in_rule
      Qwester::Answer.where(id: answer_ids_in_rule).pluck(:id)
    end

    def check_answers_exist_with_ids_matching_those_in_rule
      mismatch = answer_ids_in_rule - answers_ids_in_database_also_found_in_rule
      return if mismatch.empty?
      mismatch_report = mismatch.collect{|a| "a#{a}"}.join(", ")
      errors.add(:rule, "Answer labels [#{mismatch_report}] do not have corresponding answers in database")
    end
  end
end
