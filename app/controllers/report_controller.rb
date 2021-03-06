class ReportController < ApplicationController

  include PdfHelper

  def weekly_report
    @start_date = Date.new(params[:start_year].to_i,params[:start_month].to_i,params[:start_day].to_i) rescue nil
    @end_date = Date.new(params[:end_year].to_i,params[:end_month].to_i,params[:end_day].to_i) rescue nil
    if (@start_date > @end_date) || (@start_date > Date.today)
      flash[:notice] = 'Start date is greater than end date or Start date is greater than today'
      redirect_to :action => 'select'
      return
    end
    
    @diagnoses = ConceptName.find(:all,
      :joins =>
        "INNER JOIN obs ON
                                         concept_name.concept_id = obs.value_coded",
      :conditions => ["date_format(obs_datetime, '%Y-%m-%d') >= ? AND date_format(obs_datetime, '%Y-%m-%d') <= ?",
        @start_date, @end_date],
      :group =>   "name",
      :select => "concept_name.concept_id,concept_name.name,obs.value_coded,obs.obs_datetime,obs.voided")
    @patient = Person.find(:all,
      :joins =>
        "INNER JOIN obs ON
                                 person.person_id = obs.person_id",
      :conditions => ["date_format(obs_datetime, '%Y-%m-%d') >= ? AND date_format(obs_datetime, '%Y-%m-%d') <= ?",
        @start_date, @end_date],
      :select => "person.voided,obs.value_coded,obs.obs_datetime,obs.voided ")
  
    @times = []                         
    @data_hash = Hash.new
    start_date = @start_date
    end_date = @end_date

    while start_date >= @start_date and start_date <= @end_date
      @times << start_date
      start_date = 1.weeks.from_now(start_date.monday)
      end_date = start_date-1.day
      #end_date = 4.days.from_now(start_date)
      if end_date >= @end_date
        end_date = @end_date
      end
    end
    
    @times.each{|t|
      @diagnoses_hash = {}
      patients = []
      @patient.each{|p|
        next_start_day = 1.weeks.from_now(t.monday)
        end_day = next_start_day - 1.day
        if end_day >= @end_date
          end_day = @end_date
        end
        patients << p if p.obs_datetime.to_date >= t and p.obs_datetime.to_date <= end_day
      }
      @diagnoses.each{|d|
        count = 0
        patients.each{|patient|
          count += 1  if patient.value_coded == d.value_coded
        }
        @diagnoses_hash[d.name] = count
      }
      @data_hash["#{t}"] = @diagnoses_hash
    }

    #Now create an array to use for sorting when we get to the view
    @sort_array = []
    sort_hash = {}

    @diagnoses.each{|d|
      sum = 0
      @times.each{|t|
        @data_hash.each{|time,data|
          if t.to_date == time.to_date 
            data.each{|k,v|
              if k == d.name
                sum = sum + v
              end
            }
          end
        }


      }
      sort_hash[d.name] = sum

    }

    sort_hash = sort_hash.sort{|a,b| -1*( a[1]<=>b[1])}
    sort_hash.each{|x| @sort_array << x[0]}

    # make_and_send_pdf('/report/weekly_report', 'weekly_report.pdf')

  end

  def disaggregated_diagnosis

    @start_date = Date.new(params[:start_year].to_i,params[:start_month].to_i,params[:start_day].to_i) rescue nil
    @end_date = Date.new(params[:end_year].to_i,params[:end_month].to_i,params[:end_day].to_i) rescue nil
    if (@start_date > @end_date) || (@start_date > Date.today)
      flash[:notice] = 'Start date is greater than end date or Start date is greater than today'
      redirect_to :action => 'select'
      return
    end

    #getting an array of all diagnoses recorded within the chosen period - to avoid including existent but non recorded diagnoses
    diagnoses = ConceptName.find(:all,
      :joins =>
        "INNER JOIN obs ON
                                         concept_name.concept_id = obs.value_coded",
      :conditions => ["date_format(obs_datetime, '%Y-%m-%d') >= ? AND date_format(obs_datetime, '%Y-%m-%d') <= ?",
        @start_date, @end_date],
      :group =>   "name",
      :select => "concept_name.concept_id,concept_name.name,obs.value_coded,obs.obs_datetime,obs.voided")
    #getting list of all patients who were diagnosed within the set period-to avoid getting all patients
    @patient = Person.find(:all,
      :joins =>
        "INNER JOIN obs ON
                                 person.person_id = obs.person_id",
      :conditions => ["date_format(obs_datetime, '%Y-%m-%d') >= ? AND date_format(obs_datetime, '%Y-%m-%d') <= ?",
        @start_date, @end_date],
      :select => "person.gender,person.birthdate,person.birthdate_estimated,person.date_created,
                                      person.voided,obs.value_coded,obs.obs_datetime,obs.voided ")
  
    sort_hash = Hash.new

    #sorting the diagnoses using frequency with the highest first
    diagnoses.each{|diagnosis|
      count = 0
      @patient.each{|patient|
        if patient.value_coded == diagnosis.value_coded
          count += 1
        end
      }
      sort_hash[diagnosis.name] = count
  
    }
    #A sorted array of diagnoses to be sent to be sent to form
    @diagnoses = Array.new

    sort_hash = sort_hash.sort{|a,b| -1*( a[1]<=>b[1])}
    diagnosis_names = []
    sort_hash.each{|x| diagnosis_names << x[0]}
    diagnosis_names.each{|d|
      diagnoses.each{|diag|
        @diagnoses << diag if d == diag.name
      }
    }
   

  end

  def referral
    @start_date = Date.new(params[:start_year].to_i,params[:start_month].to_i,params[:start_day].to_i) rescue nil
    @end_date = Date.new(params[:end_year].to_i,params[:end_month].to_i,params[:end_day].to_i) rescue nil
    if (@start_date > @end_date) || (@start_date > Date.today)
      flash[:notice] = 'Start date is greater than end date or Start date is greater than today'
      redirect_to :action => 'select'
      return
    end

    @referrals = Observation.find(:all, :conditions => ["concept_id = ? AND date_format(obs_datetime, '%Y-%m-%d') >= ? AND 
                                  date_format(obs_datetime, '%Y-%m-%d') <= ?", 2227, @start_date, @end_date])
    @facilities = Observation.find(:all, :conditions => ["concept_id = ?", 2227], :group => "value_text")
  end

  def report_date_select
  end
  
  def select
  end
  def select_remote_options
    render :layout => false
  end
  def remote_report
    s_day = params[:post]['start_date(3i)'].to_i #2
    s_month = params[:post]['start_date(2i)'].to_i #12
    s_year = params[:post]['start_date(1i)'].to_i  #2008
    e_day = params[:post]['end_date(3i)'].to_i #18
    e_month = params[:post]['end_date(2i)'].to_i #1
    e_year = params[:post]['end_date(1i)'].to_i # 2009
    parameters = {'start_year' => s_year, 'start_month' => s_month, 'start_day' => s_day,'end_year' => e_year, 'end_month' => e_month, 'end_day' => e_day}

    if params[:report] == 'Weekly report'
      redirect_to :action => 'weekly_report', :params => parameters
    elsif params[:report] == 'Disaggregated Diagnoses'
      redirect_to :action => 'disaggregated_diagnosis', :params => parameters
    elsif params[:report] == 'Referrals'
      redirect_to :action => 'referral', :params => parameters
    end

  end

  def generate_pdf_report
    make_and_send_pdf('/report/weekly_report', 'weekly_report.pdf')
  end

  def issue_baby_ids

    national_ids = []

    BirthReport.find(:all, :conditions => ["acknowledged IS NOT NULL AND DATE(date_created) >= ? AND DATE(date_created) <= ?",
        params[:start_date].to_date, params[:end_date].to_date]).each{|br|
      national_ids << Patient.find(br.person_id).national_id rescue nil
    }
    
    ids = {"ids" => national_ids}
    render :text => ids.to_json
  end

  def delivered_patients
    
    @legal_identifiers = PatientIdentifierType.find(:all,
      :conditions => ["name IN ('National id', 'Old Identification Number')"]).collect{|idt| idt.id}
    @outcome_concept_id = ConceptName.find_by_name("OUTCOME").concept_id
    @delivered_concept_id = ConceptName.find_by_name("DELIVERED").concept_id
    @delivery_encounter = EncounterType.find_by_name("UPDATE OUTCOME").id

    @ids = Encounter.find_by_sql(["SELECT pid.identifier AS ident FROM encounter enc
          INNER JOIN patient_identifier pid ON pid.patient_id = enc.patient_id AND pid.identifier_type IN (?)
          INNER JOIN obs ob ON ob.encounter_id = enc.encounter_id AND ob.concept_id = ? AND ob.value_coded = ?
          WHERE enc.encounter_type = ? AND DATE(enc.encounter_datetime) BETWEEN ? AND ?
        ", @legal_identifiers, @outcome_concept_id, @delivered_concept_id, @delivery_encounter,
        params[:start_date].to_date, params[:end_date].to_date]).collect{|pd| pd.ident}
    
    render :text => {"ids" => @ids}.to_json
    
  end

end
