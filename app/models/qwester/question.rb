module Qwester
  class Question < ActiveRecord::Base
    if Qwester.rails_three?
      attr_accessible :title, :description, :ref, :answers_attributes, :multi_answer
    end

    has_many(
      :answers, -> { order 'position' },
      #:order => 'position',
      :dependent => :destroy
    )
    accepts_nested_attributes_for :answers

    has_many :questionnaires_questions

    has_many(
      :questionnaires, -> {uniq},
      :through => :questionnaires_questions,
    #:uniq => true
    )

    validates :title, :presence => true

    def build_standard_answers
      created_answers = Array.new
      Answer.standard_values.each_with_index do |value, index|
        #answer = answers.find_or_initialize_by_value(value)
        answer = answers.find_or_initialize_by(value: value)
        answer.position = index + 1
        created_answers << answer
      end
      return created_answers
    end

    def create_standard_answers
      build_standard_answers.each(&:save)
    end
  end
end