class Relationship < ActiveRecord::Base
  set_table_name :relationship
  set_primary_key :relationship_id
  include Openmrs
  belongs_to :person, :class_name => 'Person', :foreign_key => :person_a, :conditions => {:voided => 0}
  belongs_to :relation, :class_name => 'Person', :foreign_key => :person_b, :conditions => {:voided => 0}
  belongs_to :type, :class_name => "RelationshipType", :foreign_key => :relationship # no default scope, should have retired
  named_scope :guardian, :conditions => 'relationship_type.b_is_to_a = "Guardian"', :include => :type
  
  def to_s
    self.type.b_is_to_a + ": " + (relation.names.first.given_name + ' ' + relation.names.first.family_name rescue '')
  end

  def self.total_babies_in_range(start_date = DateTime.now, end_date = DateTime.now)

    birth_report_sent = "SELECT 'SENT' FROM birth_report br WHERE br.person_id = ob.person_id AND br.date_created IS NOT NULL AND br.acknowledged IS NOT NULL LIMIT 1"
    birth_report_pending = "SELECT 'PENDING' FROM birth_report br WHERE br.person_id = ob.person_id AND br.date_created IS NOT NULL AND br.acknowledged IS NULL LIMIT 1"
    birth_report_unattempted = "SELECT 'UNATTEMPTED' FROM person pr WHERE  pr.person_id = ob.person_id AND NOT ((SELECT COUNT(*) FROM birth_report br WHERE br.person_id = pr.person_id) > 0) LIMIT 1"
    
    apgar_query1 = "SELECT COALESCE(observ.value_numeric, observ.value_text) FROM obs observ
          WHERE observ.person_id = ob.person_id AND observ.concept_id = (SELECT cn.concept_id FROM concept_name cn WHERE cn.name = 'APGAR MINUTE ONE') ORDER BY observ.obs_datetime LIMIT 1"

    apgar_query2 = "SELECT COALESCE(observ.value_numeric, observ.value_text) FROM obs observ
          WHERE observ.person_id = ob.person_id AND observ.concept_id = (SELECT cn.concept_id FROM concept_name cn WHERE cn.name = 'APGAR MINUTE FIVE') ORDER BY observ.obs_datetime LIMIT 1"

    discharge_outcome_query = "SELECT COALESCE((SELECT name FROM concept_name cnm
          WHERE cnm.concept_name_id = observ.value_coded_name_id), observ.value_text) FROM obs observ
          WHERE observ.person_id = ob.person_id AND observ.concept_id = (SELECT c.concept_id FROM concept_name c WHERE c.name = 'STATUS OF BABY') ORDER BY observ.obs_datetime LIMIT 1"

    delivery_outcome_query = "SELECT COALESCE((SELECT name FROM concept_name cnm
          WHERE cnm.concept_name_id = observ.value_coded_name_id), observ.value_text) FROM obs observ
          WHERE observ.person_id = ob.person_id AND observ.concept_id = (SELECT c.concept_id FROM concept_name c WHERE c.name = 'BABY OUTCOME') ORDER BY observ.obs_datetime LIMIT 1"

    babies = Relationship.find_by_sql(["SELECT COALESCE((#{birth_report_sent}), (#{birth_report_pending}), (#{birth_report_unattempted}), 'UNKNOWN') AS br_status, client.person_id AS person_id, (#{apgar_query1}) AS apgar, (#{apgar_query2}) AS apgar2, rel.person_a AS mother, (#{discharge_outcome_query}) AS discharge_outcome,
      (#{delivery_outcome_query}) AS delivery_outcome, COALESCE(ob.value_numeric, ob.value_text) AS birth_weight, client.gender AS gender
           FROM relationship rel
      INNER JOIN person client ON rel.voided = 0 AND rel.person_b = client.person_id AND rel.relationship =
        (SELECT relationship_type_id FROM relationship_type WHERE a_is_to_b = 'Mother' AND b_is_to_a = 'Child' LIMIT 1)
      INNER JOIN obs ob ON ob.person_id = client.person_id AND ob.voided = 0
      AND ob.concept_id = (SELECT concept_id FROM concept_name WHERE name = 'BIRTH WEIGHT' LIMIT 1)
      WHERE DATE(ob.obs_datetime) BETWEEN  ? AND ? ORDER BY ob.obs_datetime DESC", start_date.to_date, end_date.to_date]).each{|bba|
      bba.birth_weight = (bba.birth_weight.to_i <= 10 && bba.birth_weight.to_i > 0) ? bba.birth_weight.to_i * 1000 : bba.birth_weight
    }
    
    babies
  end
end
