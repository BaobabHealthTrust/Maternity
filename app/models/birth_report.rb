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

  def self.unsent_between(type = "all", start_date = "1900-01-01".to_date, end_date = Date.today, user_id = "")

    results = 0

    insert = user_id.blank?? "" : "AND br.created_by = #{user_id}"

    case type

    when "all"

      reports = Relationship.find_by_sql("SELECT * FROM relationship r
        INNER JOIN birth_report br ON br.person_id = r.person_b #{insert}
        AND relationship = (SELECT relationship_type_id FROM relationship_type WHERE a_is_to_b = 'Mother' AND b_is_to_a = 'Child')
        WHERE r.voided = 0 AND br.date_created IS NOT NULL")

    when "sent"

      reports = Relationship.find_by_sql("SELECT * FROM relationship r
        INNER JOIN birth_report br ON br.person_id = r.person_b #{insert}
        AND relationship = (SELECT relationship_type_id FROM relationship_type WHERE a_is_to_b = 'Mother' AND b_is_to_a = 'Child')
        WHERE r.voided = 0 AND br.date_created IS NOT NULL AND br.acknowledged IS NOT NULL")

    when "pending"

      reports = Relationship.find_by_sql("SELECT * FROM relationship r
        INNER JOIN birth_report br ON br.person_id = r.person_b #{insert}
        AND relationship = (SELECT relationship_type_id FROM relationship_type WHERE a_is_to_b = 'Mother' AND b_is_to_a = 'Child')
        WHERE r.voided = 0 AND br.date_created IS NOT NULL AND br.acknowledged IS NULL")

    when "unattempted"

      insert = user_id.blank?? "" : "AND r.creator = #{user_id}"

      reports = Relationship.find_by_sql("SELECT * FROM relationship r
        WHERE r.relationship = (SELECT relationship_type_id FROM relationship_type WHERE a_is_to_b = 'Mother' AND b_is_to_a = 'Child')
        AND r.voided = 0 #{insert} AND NOT ((SELECT COUNT(*) FROM birth_report br WHERE br.person_id = r.person_b) > 0)")

    end

    reports.each do |res|

      if res.date_created.to_date >= start_date.to_date and res.date_created.to_date <= end_date.to_date and (Person.find(res.person_b).dead == false)
        results += 1
      end

    end

    results

  end

end