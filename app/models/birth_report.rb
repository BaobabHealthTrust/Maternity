class BirthReport < ActiveRecord::Base
	set_table_name "birth_report"
	set_primary_key "birth_report_id"

	belongs_to :person

  def self.unsent_total
    Relationship.find_by_sql("SELECT * FROM relationship r
        INNER JOIN birth_report br ON br.person_id = r.person_b
        AND relationship = (SELECT relationship_type_id FROM relationship_type WHERE a_is_to_b = 'Mother' AND b_is_to_a = 'Child')
        WHERE r.voided = 0 AND (br.acknowledged IS NULL OR br.acknowledged = '')")
  end

  def self.unsent(user_id)
    Relationship.find_by_sql("SELECT * FROM relationship r
        INNER JOIN birth_report br ON br.person_id = r.person_b
        AND relationship = (SELECT relationship_type_id FROM relationship_type WHERE a_is_to_b = 'Mother' AND b_is_to_a = 'Child')
        WHERE r.voided = 0 AND (br.acknowledged IS NULL OR br.acknowledged = '') AND br.created_by = #{user_id}")
  end

  def self.unsent_babies(user_id, patient_id)
    Relationship.find_by_sql("SELECT * FROM relationship r
        INNER JOIN birth_report br ON br.person_id = r.person_b
        AND relationship = (SELECT relationship_type_id FROM relationship_type WHERE a_is_to_b = 'Mother' AND b_is_to_a = 'Child')
        WHERE r.voided = 0 AND (br.acknowledged IS NULL OR br.acknowledged = '') 
        AND br.created_by = #{user_id} AND r.person_a = #{patient_id}")
  end
  
end
