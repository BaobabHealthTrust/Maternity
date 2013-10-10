class CohortController < ActionController::Base # < ApplicationController

  def index
    @location = GlobalProperty.find_by_property("facility.name").property_value rescue ""

    if params[:reportType]
      @reportType = params[:reportType] rescue nil
    else
      @reportType = nil
    end

  end

  def cohort

    if params[:selQtr].present?
      
      day = params[:selQtr].to_s.match(/^min=(.+)&max=(.+)$/)
			@start_date = (day ? day[1] : Date.today.strftime("%Y-%m-%d"))
			@end_date = (day ? day[2] : Date.today.strftime("%Y-%m-%d"))
      params[:start_date] = @start_date
      params[:end_date] = @end_date   
      params[:type] = "cohort"

    else
    
      @selSelect = params[:selSelect] rescue nil
      @day =  params[:day] rescue nil
      @selYear = params[:selYear] rescue nil
      @selWeek = params[:selWeek] rescue nil
      @selMonth = params[:selMonth] rescue nil
      @selQtr = "#{params[:selQtr].gsub(/&/, "_")}" rescue nil

      @start_date = params[:start_date] rescue nil
      @end_date = params[:end_date] rescue nil

      @start_time = params[:start_time] rescue nil
      @end_time = params[:end_time] rescue nil
      
    end
    
    @reportType = params[:reportType] rescue ""
   
    
    render :layout => "menu"
  end

  def cohort_print
   
    @location_name = GlobalProperty.find_by_property('facility.name').property_value rescue ""
    
    @reportType = params[:reportType] rescue ""    

    @start_date = nil
    @end_date = nil
    
    case params[:selSelect]
    when "day"
      @start_date = params[:day]
      @end_date = params[:day]

    when "week"
      
      @start_date = (("#{params[:selYear]}-01-01".to_date) + (params[:selWeek].to_i * 7)) - 
        ("#{params[:selYear]}-01-01".to_date.strftime("%w").to_i)
      
      @end_date = (("#{params[:selYear]}-01-01".to_date) + (params[:selWeek].to_i * 7)) +
        6 - ("#{params[:selYear]}-01-01".to_date.strftime("%w").to_i)

    when "month"
      @start_date = ("#{params[:selYear]}-#{params[:selMonth]}-01").to_date.strftime("%Y-%m-%d")
      @end_date = ("#{params[:selYear]}-#{params[:selMonth]}-#{ (params[:selMonth].to_i != 12 ?
        ("2010-#{params[:selMonth].to_i + 1}-01".to_date - 1).strftime("%d") : 31) }").to_date.strftime("%Y-%m-%d")

    when "year"
      @start_date = ("#{params[:selYear]}-01-01").to_date.strftime("%Y-%m-%d")
      @end_date = ("#{params[:selYear]}-12-31").to_date.strftime("%Y-%m-%d")

    when "quarter"
      day = params[:selQtr].to_s.match(/^min=(.+)_max=(.+)$/)

      @start_date = (day ? day[1] : Date.today.strftime("%Y-%m-%d"))
      @end_date = (day ? day[2] : Date.today.strftime("%Y-%m-%d"))

    when "range"
      @start_date = params[:start_date]
      @end_date = params[:end_date]

    end

    @section = nil

    case @reportType.to_i
    when 2:
        @section = Location.find_by_name("Labour Ward").location_id rescue nil
    when 3:
        @section = Location.find_by_name("Ante-Natal Ward").location_id rescue nil
    when 4:
        @section = Location.find_by_name("Post-Natal Ward").location_id rescue nil
    when 5:
        @section = Location.find_by_name("Gynaecology Ward").location_id rescue nil
    when 6:
        @section = Location.find_by_name("Post-Natal Ward (High Risk)").location_id rescue nil
    when 7:
        @section = Location.find_by_name("Post-Natal Ward (Low Risk)").location_id rescue nil
    when 8:
        @section = Location.find_by_name("Theater").location_id rescue nil
    end

    report = Reports::Cohort.new(@start_date, @end_date, @section)

    # @fields = [
    #   [
    #     "Field Label",
    #     "0730_1630 Value",
    #     "1630_0730 Value"
    #   ]
    # ]
    @fields = [
      ["Admissions", report.admissions0730_1630, report.admissions1630_0730],
      ["Discharges", report.discharged0730_1630, report.discharged1630_0730],
      ["Referrals (Out)", report.referralsOut0730_1630, report.referralsOut1630_0730],
      ["Referrals (In)", report.referrals0730_1630, report.referrals1630_0730],
      ["Maternal Deaths", report.maternal_deaths0730_1630, report.maternal_deaths1630_0730],
      ["C/Section", report.cesarean0730_1630, report.cesarean1630_0730],
      ["SVDs", report.svds0730_1630, report.svds1630_0730],
      ["Vacuum Extraction", report.vacuum0730_1630, report.vacuum1630_0730],
      ["Breech Delivery", report.breech0730_1630, report.breech1630_0730],
      ["Ruptured Uterus", report.ruptured_uterus0730_1630, report.ruptured_uterus1630_0730],
      ["Triplets", report.triplets0730_1630, report.triplets1630_0730],
      ["Twins", report.twins0730_1630, report.twins1630_0730],
      ["BBA", report.bba0730_1630, report.bba1630_0730],
      # ["Antenatal Mothers", "", ""],
      # ["Postnatal Mothers", "", ""],
      ["Macerated Still Births", report.macerated0730_1630, report.macerated1630_0730],
      ["Fresh Still Births", report.fresh0730_1630, report.fresh1630_0730],
      ["Waiting Mothers", report.waiting_bd_ante_w0730_1630, report.waiting_bd_ante_w1630_0730],
      ["Continued Care", report.labour_to_ante_w0730_1630, report.labour_to_ante_w1630_0730],
      ["Total Clients", report.total_patients0730_1630, report.total_patients1630_0730],
      ["Total Mothers", report.total_patients0730_1630, report.total_patients1630_0730],
      ["Total Babies", report.babies0730_1630, report.babies1630_0730],
      ["Transfer (Ante-Natal - Labour)", 
        report.source_to_destination_ward0730_1630("ANTE-NATAL WARD", "LABOUR WARD"),
        report.source_to_destination_ward1630_0730("ANTE-NATAL WARD", "LABOUR WARD")],
      ["Transfer (Labour - Ante-Natal)",
        report.source_to_destination_ward0730_1630("LABOUR WARD", "ANTENATAL WARD"),
        report.source_to_destination_ward1630_0730("LABOUR WARD", "ANTENATAL WARD")],
      ["Transfer (PostNatal - Labour)",
        report.source_to_destination_ward0730_1630("POST-NATAL WARD", "LABOUR WARD"),
        report.source_to_destination_ward1630_0730("POST-NATAL WARD", "LABOUR WARD")],
      ["Transfer (Labour - Post-Natal)",
        report.source_to_destination_ward0730_1630("LABOUR WARD", "POSTNATAL WARD"),
        report.source_to_destination_ward1630_0730("LABOUR WARD", "POSTNATAL WARD")],
      ["Transfer (Post-Natal Ward (Low Risk) - Labour)",
        report.source_to_destination_ward0730_1630("Post-Natal Ward (Low Risk)", "LABOUR WARD"),
        report.source_to_destination_ward1630_0730("Post-Natal Ward (Low Risk)", "LABOUR WARD")],
      ["Transfer (Labour - Post-Natal Ward (Low Risk))",
        report.source_to_destination_ward0730_1630("LABOUR WARD", "Post-Natal Ward (Low Risk)"),
        report.source_to_destination_ward1630_0730("LABOUR WARD", "Post-Natal Ward (Low Risk)")],
      ["Transfer (Post-Natal Ward (High Risk) - Labour)",
        report.source_to_destination_ward0730_1630("Post-Natal Ward (High Risk)", "LABOUR WARD"),
        report.source_to_destination_ward1630_0730("Post-Natal Ward (High Risk)", "LABOUR WARD")],
      ["Transfer (Labour - Post-Natal Ward (High Risk))",
        report.source_to_destination_ward0730_1630("LABOUR WARD", "Post-Natal Ward (High Risk)"),
        report.source_to_destination_ward1630_0730("LABOUR WARD", "Post-Natal Ward (High Risk)")],
      ["Transfer (Post-Natal Ward (High Risk) - Post-Natal Ward (Low Risk))",
        report.source_to_destination_ward0730_1630("Post-Natal Ward (High Risk)", "Post-Natal Ward (Low Risk)"),
        report.source_to_destination_ward1630_0730("Post-Natal Ward (High Risk)", "Post-Natal Ward (Low Risk)")],
      ["Transfer (Post-Natal Ward (Low Risk) - Post-Natal Ward (High Risk))",
        report.source_to_destination_ward0730_1630("Post-Natal Ward (Low Risk)", "Post-Natal Ward (High Risk)"),
        report.source_to_destination_ward1630_0730("Post-Natal Ward (Low Risk)", "Post-Natal Ward (High Risk)")],
      ["Transfer (Gynaecology Ward - Labour)",
        report.source_to_destination_ward0730_1630("Gynaecology Ward", "LABOUR WARD"),
        report.source_to_destination_ward1630_0730("Gynaecology Ward", "LABOUR WARD")],
      ["Transfer (Labour - Gynaecology Ward)",
        report.source_to_destination_ward0730_1630("LABOUR WARD", "Gynaecology Ward"),
        report.source_to_destination_ward1630_0730("LABOUR WARD", "Gynaecology Ward")],
      ["Transfer (Gynaecology Ward - Post-Natal Ward (High Risk))",
        report.source_to_destination_ward0730_1630("Gynaecology Ward", "Post-Natal Ward (High Risk)"),
        report.source_to_destination_ward1630_0730("Gynaecology Ward", "Post-Natal Ward (High Risk)")],
      ["Transfer (Post-Natal Ward (High Risk) - Gynaecology Ward)",
        report.source_to_destination_ward0730_1630("Post-Natal Ward (High Risk)", "Gynaecology Ward"),
        report.source_to_destination_ward1630_0730("Post-Natal Ward (High Risk)", "Gynaecology Ward")],
      ["Transfer (Gynaecology Ward - Post-Natal Ward (Low Risk))",
        report.source_to_destination_ward0730_1630("Gynaecology Ward", "Post-Natal Ward (Low Risk)"),
        report.source_to_destination_ward1630_0730("Gynaecology Ward", "Post-Natal Ward (Low Risk)")],
      ["Transfer (Post-Natal Ward (Low Risk) - Gynaecology Ward)",
        report.source_to_destination_ward0730_1630("Post-Natal Ward (Low Risk)", "Gynaecology Ward"),
        report.source_to_destination_ward1630_0730("Post-Natal Ward (Low Risk)", "Gynaecology Ward")],
      ["Fistula", report.fistula0730_1630, report.fistula1630_0730],
      ["Post Partum Haemorrhage", report.postpartum0730_1630, report.postpartum1630_0730],
      ["Ante Partum Haemorrhage", report.antepartum0730_1630, report.antepartum1630_0730],
      ["Eclampsia", report.eclampsia0730_1630, report.eclampsia1630_0730],
      ["Pre-Eclampsia", report.pre_eclampsia0730_1630, report.pre_eclampsia1630_0730],
      ["Anaemia", report.anaemia0730_1630, report.anaemia1630_0730],
      ["Malaria", report.malaria0730_1630, report.malaria1630_0730],
      ["Pre-Mature Labour", report.pre_mature_labour0730_1630, report.pre_mature_labour1630_0730],
      ["Pre-Mature Membrane Rapture", report.pre_mature_rapture0730_1630, report.pre_mature_rapture1630_0730],
      ["Abscondees", report.absconded0730_1630, report.absconded1630_0730],
      ["Abortions", report.abortion0730_1630, report.abortion1630_0730],
      ["Cancer of Cervix", report.cancer0730_1630, report.cancer1630_0730],
      ["Fibroids", report.fibroids0730_1630, report.fibroids1630_0730],
      ["Molar Pregnancy", report.molar0730_1630, report.molar1630_0730],
      ["Pelvic Inflamatory Disease", report.pelvic0730_1630, report.pelvic1630_0730],
      ["Ectopic Pregnancy", report.ectopic0730_1630, report.ectopic1630_0730]
    ]

    @specified_period = report.specified_period

    render :layout => false
  end

  def print_cohort
    # raise request.env["HTTP_HOST"].to_yaml
   
    @selSelect = params[:selSelect] rescue ""
    @day =  params[:day] rescue ""
    @selYear = params[:selYear] rescue ""
    @selWeek = params[:selWeek] rescue ""
    @selMonth = params[:selMonth] rescue ""
    @selQtr = params[:selQtr] rescue ""
    @start_date = params[:start_date] rescue ""
    @end_date = params[:end_date] rescue ""

    @reportType = params[:reportType] rescue ""

    if params
      link = ""



      if CoreService.get_global_property_value("extended_diagnoses_report").to_s == "true"
        link = "/cohort/#{ (@reportType.to_i == 2 ? "diagnoses_report_extended" : (@reportType.to_i == 3 ? "baby_matrix_printable" : "report")) }" +
          "?start_date=#{@start_date}+#{@start_time}&end_date=#{@end_date}+#{@end_time}&reportType=#{@reportType}"
      else
        link = "/cohort/#{ (@reportType.to_i == 2 ? "diagnoses_report" :  (@reportType.to_i == 3 ? "baby_matrix_printable" : "report"))}" +
          "?start_date=#{@start_date}+#{@start_time}&end_date=#{@end_date}+#{@end_time}&reportType=#{@reportType}"
      end
      #t1 = Thread.new{
      # Kernel.system "htmldoc --webpage -f /tmp/output-" + session[:user_id].to_s + ".pdf \"http://" +
      #  request.env["HTTP_HOST"] + link + "\"\n"

      Kernel.system "wkhtmltopdf -s A4 \"http://" +
        request.env["HTTP_HOST"] + "#{link}\" \"/tmp/output-" + session[:user_id].to_s + ".pdf\" \n"
      # }

      t2 = Thread.new{
        sleep(5)
        Kernel.system "lp /tmp/output-" + session[:user_id].to_s + ".pdf\n"
      }

      t3 = Thread.new{
        sleep(10)
        Kernel.system "rm /tmp/output-" + session[:user_id].to_s + ".pdf\n"
      }

    end

    redirect_to "/cohort/cohort?selSelect=#{ @selSelect }&day=#{ @day }" +
      "&selYear=#{ @selYear }&selWeek=#{ @selWeek }&selMonth=#{ @selMonth }&selQtr=#{ @selQtr }" +
      "&start_date=#{ @start_date }&end_date=#{ @end_date }&reportType=#{@reportType}" and return
  end

  def report
    @section = Location.find(params[:location_id]).name rescue ""
    
    @start_date = (params[:start_date].to_time rescue Time.now)
    
    @end_date = (params[:end_date].to_time rescue Time.now)
    
    @group1_start = @start_date
    
    @group1_end = (@end_date <= (@start_date + 12.hour) ? @end_date : (@start_date + 12.hour))
        
    @group2_start = (@end_date > (@start_date + 12.hour) ? (@start_date + 12.hour) : nil)
    
    @group2_end = (@end_date > (@start_date + 12.hour) ? @end_date : nil)
       
    render :layout => false
  end
  
  def diagnoses_report
    @section = Location.find(params[:location_id]).name rescue ""
    
    @start_date = (params[:start_date].to_time rescue Time.now)
    
    @end_date = (params[:end_date].to_time rescue Time.now)
    
    @group1_start = @start_date
    
    @group1_end = (@end_date <= (@start_date + 12.hour) ? @end_date : (@start_date + 12.hour))
        
    @group2_start = (@end_date > (@start_date + 12.hour) ? (@start_date + 12.hour) : nil)
    
    @group2_end = (@end_date > (@start_date + 12.hour) ? @end_date : nil)
       
    render :layout => false
  end

  def diagnoses_report_extended
    @section = Location.find(params[:location_id]).name rescue ""
    
    @start_date = (params[:start_date].to_time rescue Time.now)
    
    @end_date = (params[:end_date].to_time rescue Time.now)
    
    @group1_start = @start_date
    
    @group1_end = (@end_date <= (@start_date + 12.hour) ? @end_date : (@start_date + 12.hour))
        
    @group2_start = (@end_date > (@start_date + 12.hour) ? (@start_date + 12.hour) : nil)
    
    @group2_end = (@end_date > (@start_date + 12.hour) ? @end_date : nil)
       
    render :layout => false
  end
  
  def q
	
    if params[:parent]

      procedure(params[:start_date], params[:end_date], params[:group], params[:field], params[:parent])
    elsif params[:like]
      diagnosis_regex(params[:start_date], params[:end_date], params[:group], params[:field])
    elsif params[:field] && !params[:ext] && !params[:pro] && !params[:proc]
      case params[:field]
      when "admissions"
        admissions(params[:start_date], params[:end_date], params[:group], params[:field])
      when "svd"
        svd(params[:start_date], params[:end_date], params[:group], params[:field])
      when "c_section"
        c_section(params[:start_date], params[:end_date], params[:group], params[:field])
      when "vacuum_extraction"
        vacuum_extraction(params[:start_date], params[:end_date], params[:group], params[:field])
      when "breech_delivery"
        breech_delivery(params[:start_date], params[:end_date], params[:group], params[:field])
      when "twins"
        twins(params[:start_date], params[:end_date], params[:group], params[:field])
      when "triplets"
        triplets(params[:start_date], params[:end_date], params[:group], params[:field])
      when "live_births"
        live_births(params[:start_date], params[:end_date], params[:group], params[:field])
      when "macerated"
        macerated(params[:start_date], params[:end_date], params[:group], params[:field])
      when "fresh"
        fresh(params[:start_date], params[:end_date], params[:group], params[:field])
      when "neonatal_death"
        neonatal_death(params[:start_date], params[:end_date], params[:group], params[:field])
      when "maternal_death"
        maternal_death(params[:start_date], params[:end_date], params[:group], params[:field])
      when "bba"
        bba(params[:start_date], params[:end_date], params[:group], params[:field])
      when "referral_out"
        referral_out(params[:start_date], params[:end_date], params[:group], params[:field])
      when "referral_in"
        referral_in(params[:start_date], params[:end_date], params[:group], params[:field])
      when "discharges"
        discharges(params[:start_date], params[:end_date], params[:group], params[:field])
      when "ante_natal_ward"
        ante_natal_ward(params[:start_date], params[:end_date], params[:group], params[:field])
      when "discharges_low_risk"
        discharges_low_risk(params[:start_date], params[:end_date], params[:group], params[:field])
      when "discharges_high_risk"
        discharges_high_risk(params[:start_date], params[:end_date], params[:group], params[:field])
      when "abscondees"
        abscondees(params[:start_date], params[:end_date], params[:group], params[:field])
      when "post_mothers"
        post_mothers(params[:start_date], params[:end_date], params[:group], params[:field])
      when "post_babies"
        post_babies(params[:start_date], params[:end_date], params[:group], params[:field])
      when "ante_labor"
        ante_labor(params[:start_date], params[:end_date], params[:group], params[:field])
      when "post_labor"
        post_labor(params[:start_date], params[:end_date], params[:group], params[:field])
      when "labor_high"
        labor_high(params[:start_date], params[:end_date], params[:group], params[:field])
      when "labor_low"
        labor_low(params[:start_date], params[:end_date], params[:group], params[:field])
      when "theatre_high"
        theatre_high(params[:start_date], params[:end_date], params[:group], params[:field])
      when "ante_theatre"
        ante_theatre(params[:start_date], params[:end_date], params[:group], params[:field])
      when "labor_gynae"
        labor_gynae(params[:start_date], params[:end_date], params[:group], params[:field])
      when "gynae_labor"
        gynae_labor(params[:start_date], params[:end_date], params[:group], params[:field])
      when "labor_ante"
        labor_ante(params[:start_date], params[:end_date], params[:group], params[:field])
      when "total_deliveries"
        total_deliveries(params[:start_date], params[:end_date], params[:group], params[:field])
      when "premature_labour"
        premature_labour(params[:start_date], params[:end_date], params[:group], params[:field])
      when "abortions"
        abortions(params[:start_date], params[:end_date], params[:group], params[:field])
      when "cancer_of_cervix"
        cancer_of_cervix(params[:start_date], params[:end_date], params[:group], params[:field])
      when "molar_pregnancy"
        molar_pregnancy(params[:start_date], params[:end_date], params[:group], params[:field])
      when "fibriods"
        fibriods(params[:start_date], params[:end_date], params[:group], params[:field])
      when "pelvic_inflamatory_disease"
        pelvic_inflamatory_disease(params[:start_date], params[:end_date], params[:group], params[:field])
      when "anaemia"
        anaemia(params[:start_date], params[:end_date], params[:group], params[:field])
      when "malaria"
        malaria(params[:start_date], params[:end_date], params[:group], params[:field])
      when "post_partum"
        post_partum(params[:start_date], params[:end_date], params[:group], params[:field])
      when "haemorrhage"
        haemorrhage(params[:start_date], params[:end_date], params[:group], params[:field])
      when "ante_partum"
        ante_partum(params[:start_date], params[:end_date], params[:group], params[:field])
      when "pre_eclampsia"
        pre_eclampsia(params[:start_date], params[:end_date], params[:group], params[:field])
      when "eclampsia"
        eclampsia(params[:start_date], params[:end_date], params[:group], params[:field])
      when "premature_labour"
        premature_labour(params[:start_date], params[:end_date], params[:group], params[:field])
      when "premature_membranes_rapture"
        premature_membranes_rapture(params[:start_date], params[:end_date], params[:group], params[:field])
      when "laparatomy"
        laparatomy(params[:start_date], params[:end_date], params[:group], params[:field])
      when "ruptured_uterus"
        ruptured_uterus(params[:start_date], params[:end_date], params[:group], params[:field])
      end    
    elsif !params[:proc]
      diagnosis(params[:start_date], params[:end_date], params[:group], params[:field])
    end           
  end
  
  def admissions(startdate = Time.now, enddate = Time.now, group = 1, field = "")
    
    patients = PatientReport.find(:all, :conditions => ["COALESCE(admission_ward, '') = '' AND admission_date >= ? AND admission_date <= ?", startdate, enddate]).collect{|p| p.patient_id}.uniq
    
    render :text => patients.to_json
  end

  def total_deliveries(startdate = Time.now, enddate = Time.now, group = 1, field = "")
    patients = PatientReport.find(:all, :conditions => ["COALESCE(delivery_mode, '') != '' " + 
          "AND delivery_date >= ? AND delivery_date <= ?", startdate, enddate]).collect{|p| p.patient_id}
    
    render :text => patients.to_json
  end

  def svd(startdate = Time.now, enddate = Time.now, group = 1, field = "")
    patients = PatientReport.find(:all, :conditions => ["COALESCE(delivery_mode, '') = 'SPONTANEOUS VAGINAL DELIVERY' " + 
          "AND delivery_date >= ? AND delivery_date <= ?", startdate, enddate]).collect{|p| p.patient_id} #.uniq
    
    render :text => patients.to_json
  end

  def c_section(startdate = Time.now, enddate = Time.now, group = 1, field = "")
    patients = PatientReport.find(:all, :conditions => ["COALESCE(delivery_mode, '') = 'Caesarean section' " + 
          "AND delivery_date >= ? AND delivery_date <= ?", startdate, enddate]).collect{|p| p.patient_id} #.uniq
    
    render :text => patients.to_json
  end

  def vacuum_extraction(startdate = Time.now, enddate = Time.now, group = 1, field = "")
    patients = PatientReport.find(:all, :conditions => ["COALESCE(delivery_mode, '') = 'Vacuum extraction delivery' " + 
          "AND delivery_date >= ? AND delivery_date <= ?", startdate, enddate]).collect{|p| p.patient_id} #.uniq
    
    render :text => patients.to_json
  end

  def breech_delivery(startdate = Time.now, enddate = Time.now, group = 1, field = "")
    patients = PatientReport.find(:all, :conditions => ["COALESCE(delivery_mode, '') = 'Breech delivery' " + 
          "AND delivery_date >= ? AND delivery_date <= ?", startdate, enddate]).collect{|p| p.patient_id} #.uniq
    
    render :text => patients.to_json
  end

  def twins(startdate = Time.now, enddate = Time.now, group = 1, field = "")
    patients = PatientReport.find(:all, :conditions => ["COALESCE(babies, '') = 2 " + 
          "AND birthdate >= ? AND birthdate <= ?", startdate, enddate]).collect{|p| p.patient_id} #.uniq
    
    render :text => patients.to_json
  end

  def triplets(startdate = Time.now, enddate = Time.now, group = 1, field = "")
    patients = PatientReport.find(:all, :conditions => ["COALESCE(babies, '') = 3 " + 
          "AND birthdate >= ? AND birthdate <= ?", startdate, enddate]).collect{|p| p.patient_id} #.uniq
    
    render :text => patients.to_json
  end

  def live_births(startdate = Time.now, enddate = Time.now, group = 1, field = "")
    patients = PatientReport.find(:all, :conditions => ["COALESCE(baby_outcome, '') = 'Alive' " + 
          "AND baby_outcome_date >= ? AND baby_outcome_date <= ?", startdate, enddate]).collect{|p| p.patient_id} #.uniq
    
    render :text => patients.to_json
  end

  def macerated(startdate = Time.now, enddate = Time.now, group = 1, field = "")
    patients = PatientReport.find(:all, :conditions => ["COALESCE(baby_outcome, '') = 'Macerated still birth' " + 
          "AND baby_outcome_date >= ? AND baby_outcome_date <= ?", startdate, enddate]).collect{|p| p.patient_id} #.uniq
    
    render :text => patients.to_json
  end

  def fresh(startdate = Time.now, enddate = Time.now, group = 1, field = "")
    patients = PatientReport.find(:all, :conditions => ["COALESCE(baby_outcome, '') = 'Fresh still birth' " + 
          "AND baby_outcome_date >= ? AND baby_outcome_date <= ?", startdate, enddate]).collect{|p| p.patient_id} #.uniq
    
    render :text => patients.to_json
  end

  def neonatal_death(startdate = Time.now, enddate = Time.now, group = 1, field = "")
    patients = PatientReport.find(:all, :conditions => ["COALESCE(baby_outcome, '') = 'Neonatal death' " + 
          "AND baby_outcome_date >= ? AND baby_outcome_date <= ?", startdate, enddate]).collect{|p| p.patient_id} #.uniq
    
    render :text => patients.to_json
  end

  def maternal_death(startdate = Time.now, enddate = Time.now, group = 1, field = "")
    patients = PatientReport.find(:all, :conditions => ["COALESCE(outcome, '') = 'Patient died' " + 
          "AND outcome_date >= ? AND outcome_date <= ?", startdate, enddate]).collect{|p| p.patient_id} #.uniq
    
    render :text => patients.to_json
  end

  def bba(startdate = Time.now, enddate = Time.now, group = 1, field = "")
    patients = []
      
    PatientReport.find(:all, :conditions => ["COALESCE(bba_babies, '') != '' " + 
          "AND bba_date >= ? AND bba_date <= ?", startdate, enddate]).each{|p| 
      (1..(p.bba_babies.to_i)).each{|b|
        patients << p.patient_id
      }
    }
    
    render :text => patients.to_json
  end

  def referral_out(startdate = Time.now, enddate = Time.now, group = 1, field = "")
    patients = PatientReport.find(:all, :conditions => ["COALESCE(referral_out, '') != '' " + 
          "AND referral_out >= ? AND referral_out <= ?", startdate, enddate]).collect{|p| p.patient_id} #.uniq
    
    render :text => patients.to_json
  end

  def referral_in(startdate = Time.now, enddate = Time.now, group = 1, field = "")
    patients = PatientReport.find(:all, :conditions => ["COALESCE(referral_in, '') != '' " + 
          "AND referral_in >= ? AND referral_in <= ?", startdate, enddate]).collect{|p| p.patient_id} #.uniq
    
    render :text => patients.to_json
  end

  def discharges(startdate = Time.now, enddate = Time.now, group = 1, field = "")
    patients = PatientReport.find(:all, :conditions => ["COALESCE(outcome, '') = 'Discharged' " + 
          "AND outcome_date >= ? AND outcome_date <= ?", startdate, enddate]).collect{|p| p.patient_id} #.uniq
    
    render :text => patients.to_json
  end

  def ante_natal_ward(startdate = Time.now, enddate = Time.now, group = 1, field = "")
    patients = PatientReport.find(:all, :conditions => ["COALESCE(discharge_ward, '') = 'Ante-Natal Ward' " +
          "AND discharged >= ? AND discharged <= ?", startdate, enddate]).collect{|p| p.patient_id} #.uniq

    render :text => patients.to_json
  end

  def discharges_low_risk(startdate = Time.now, enddate = Time.now, group = 1, field = "")
    patients = PatientReport.find(:all, :conditions => ["COALESCE(discharge_ward, '') = 'Post-Natal Ward (Low Risk)' " +
          "AND discharged >= ? AND discharged <= ?", startdate, enddate]).collect{|p| p.patient_id} #.uniq

    render :text => patients.to_json
  end

  def discharges_high_risk(startdate = Time.now, enddate = Time.now, group = 1, field = "")
    patients = PatientReport.find(:all, :conditions => ["COALESCE(discharge_ward, '') = 'Post-Natal Ward (High Risk)' " +
          "AND discharged >= ? AND discharged <= ?", startdate, enddate]).collect{|p| p.patient_id} #.uniq

    render :text => patients.to_json
  end

  def abscondees(startdate = Time.now, enddate = Time.now, group = 1, field = "")
    patients = PatientReport.find(:all, :conditions => ["COALESCE(outcome, '') = 'Absconded' " + 
          "AND outcome_date >= ? AND outcome_date <= ?", startdate, enddate]).collect{|p| p.patient_id} #.uniq
    
    render :text => patients.to_json
  end

  def post_mothers(startdate = Time.now, enddate = Time.now, group = 1, field = "")
    patients = PatientReport.find(:all, :conditions => ["(COALESCE(last_ward_where_seen, '') = 'Post-Natal Ward' OR " + 
          "COALESCE(last_ward_where_seen, '') = 'Post-Natal Ward (High Risk)' OR COALESCE(last_ward_where_seen, '') = " + 
          "'Post-Natal Ward (Low Risk)') AND last_ward_where_seen_date >= ? AND last_ward_where_seen_date <= ?", 
        startdate, enddate]).collect{|p| p.patient_id} #.uniq
    
    render :text => patients.to_json
  end

  def post_babies(startdate = Time.now, enddate = Time.now, group = 1, field = "")
    patients = PatientReport.find(:all, :conditions => ["(COALESCE(last_ward_where_seen, '') = 'Post-Natal Ward' OR " + 
          "COALESCE(last_ward_where_seen, '') = 'Post-Natal Ward (High Risk)' OR COALESCE(last_ward_where_seen, '') = " + 
          "'Post-Natal Ward (Low Risk)') AND COALESCE(delivery_mode, '') != '' AND last_ward_where_seen_date >= ? " + 
          "AND last_ward_where_seen_date <= ?", startdate, enddate]).collect{|p| p.patient_id}
    
    render :text => patients.to_json
  end

  def ante_labor(startdate = Time.now, enddate = Time.now, group = 1, field = "")
    patients = PatientReport.find(:all, :conditions => ["COALESCE(source_ward, '') = 'Ante-Natal Ward' AND " + 
          "COALESCE(destination_ward, '') = 'Labour Ward' " + 
          "AND internal_transfer_date >= ? AND internal_transfer_date <= ?", startdate, enddate]).collect{|p| p.patient_id}.uniq
    
    render :text => patients.to_json
  end

  def post_labor(startdate = Time.now, enddate = Time.now, group = 1, field = "")
    patients = PatientReport.find(:all, :conditions => ["(COALESCE(source_ward, '') = 'Post-Natal Ward' OR " + 
          "COALESCE(source_ward, '') = 'Post-Natal Ward (High Risk)' OR COALESCE(source_ward, '') = 'Post-Natal Ward (Low Risk)') AND " + 
          "COALESCE(destination_ward, '') = 'Labour Ward' " + 
          "AND internal_transfer_date >= ? AND internal_transfer_date <= ?", startdate, enddate]).collect{|p| p.patient_id}.uniq
    
    render :text => patients.to_json
  end

  def labor_high(startdate = Time.now, enddate = Time.now, group = 1, field = "")
    patients = PatientReport.find(:all, :conditions => ["COALESCE(source_ward, '') = 'Labour Ward' AND " + 
          "COALESCE(destination_ward, '') = 'Post-Natal Ward (High Risk)' " + 
          "AND internal_transfer_date >= ? AND internal_transfer_date <= ?", startdate, enddate]).collect{|p| p.patient_id}.uniq
    
    render :text => patients.to_json
  end

  def labor_ante(startdate = Time.now, enddate = Time.now, group = 1, field = "")
    patients = PatientReport.find(:all, :conditions => ["COALESCE(source_ward, '') = 'Labour Ward' AND " + 
          "COALESCE(destination_ward, '') = 'Ante-Natal Ward' " + 
          "AND internal_transfer_date >= ? AND internal_transfer_date <= ?", startdate, enddate]).collect{|p| p.patient_id}.uniq
    
    render :text => patients.to_json
  end

  def labor_low(startdate = Time.now, enddate = Time.now, group = 1, field = "")
    patients = PatientReport.find(:all, :conditions => ["COALESCE(source_ward, '') = 'Labour Ward' AND " + 
          "COALESCE(destination_ward, '') = 'Post-Natal Ward (Low Risk)' " + 
          "AND internal_transfer_date >= ? AND internal_transfer_date <= ?", startdate, enddate]).collect{|p| p.patient_id}.uniq
    
    render :text => patients.to_json
  end

  def theatre_high(startdate = Time.now, enddate = Time.now, group = 1, field = "")
    patients = PatientReport.find(:all, :conditions => ["(COALESCE(source_ward, '') = 'Theater' " + 
          "OR COALESCE(source_ward, '') = 'Theatre') AND " + 
          "COALESCE(destination_ward, '') = 'Post-Natal Ward (High Risk)' " + 
          "AND internal_transfer_date >= ? AND internal_transfer_date <= ?", startdate, enddate]).collect{|p| p.patient_id}.uniq
    
    render :text => patients.to_json
  end

  def ante_theatre(startdate = Time.now, enddate = Time.now, group = 1, field = "")
    patients = PatientReport.find(:all, :conditions => ["COALESCE(source_ward, '') = 'Ante-Natal Ward' AND " + 
          "(COALESCE(destination_ward, '') = 'Theater' OR COALESCE(destination_ward, '') = 'Theatre') " + 
          "AND internal_transfer_date >= ? AND internal_transfer_date <= ?", startdate, enddate]).collect{|p| p.patient_id}.uniq
    
    render :text => patients.to_json
  end

  def labor_gynae(startdate = Time.now, enddate = Time.now, group = 1, field = "")
    patients = PatientReport.find(:all, :conditions => ["COALESCE(source_ward, '') = 'Labour Ward' AND " + 
          "COALESCE(destination_ward, '') = 'Gynaecology Ward' " + 
          "AND internal_transfer_date >= ? AND internal_transfer_date <= ?", startdate, enddate]).collect{|p| p.patient_id}.uniq
    
    render :text => patients.to_json
  end

  def gynae_labor(startdate = Time.now, enddate = Time.now, group = 1, field = "")
    patients = PatientReport.find(:all, :conditions => ["COALESCE(source_ward, '') = 'Gynaecology Ward' AND " + 
          "COALESCE(destination_ward, '') = 'Labour Ward' " + 
          "AND internal_transfer_date >= ? AND internal_transfer_date <= ?", startdate, enddate]).collect{|p| p.patient_id}.uniq
    
    render :text => patients.to_json
  end
  
  # DIAGNOSES
  def premature_labour(startdate = Time.now, enddate = Time.now, group = 1, field = "")
    patients = PatientReport.find(:all, :conditions => ["diagnosis = ? AND diagnosis_date >= ? AND diagnosis_date <= ?", 
        "Premature Labour", startdate, enddate]).collect{|p| p.patient_id}.uniq

    render :text => patients.to_json
  end

  def abortions(startdate = Time.now, enddate = Time.now, group = 1, field = "")
    patients = PatientReport.find(:all, :conditions => ["diagnosis regexp ? AND diagnosis_date >= ? AND diagnosis_date <= ?",
        "Abortion", startdate, enddate]).collect{|p| p.patient_id}.uniq

    render :text => patients.to_json
  end

  def cancer_of_cervix(startdate = Time.now, enddate = Time.now, group = 1, field = "")
    patients = PatientReport.find(:all, :conditions => ["diagnosis = ? AND diagnosis_date >= ? AND diagnosis_date <= ?", 
        "Cancer of Cervix", startdate, enddate]).collect{|p| p.patient_id}.uniq

    render :text => patients.to_json
  end

  def molar_pregnancy(startdate = Time.now, enddate = Time.now, group = 1, field = "")
    patients = PatientReport.find(:all, :conditions => ["diagnosis = ? AND diagnosis_date >= ? AND diagnosis_date <= ?", 
        "Molar Pregnancy", startdate, enddate]).collect{|p| p.patient_id}.uniq

    render :text => patients.to_json
  end

  def fibriods(startdate = Time.now, enddate = Time.now, group = 1, field = "")
    patients = PatientReport.find(:all, :conditions => ["diagnosis LIKE ? AND diagnosis_date >= ? AND diagnosis_date <= ?", 
        "%Fibroid%", startdate, enddate]).collect{|p| p.patient_id}.uniq

    render :text => patients.to_json
  end

  def pelvic_inflamatory_disease(startdate = Time.now, enddate = Time.now, group = 1, field = "")
    patients = PatientReport.find(:all, :conditions => ["diagnosis = ? AND diagnosis_date >= ? AND diagnosis_date <= ?", 
        "Pelvic Inflammatory Disease", startdate, enddate]).collect{|p| p.patient_id}.uniq

    render :text => patients.to_json
  end

  def anaemia(startdate = Time.now, enddate = Time.now, group = 1, field = "")
    patients = PatientReport.find(:all, :conditions => ["diagnosis = ? AND diagnosis_date >= ? AND diagnosis_date <= ?", 
        "Anaemia", startdate, enddate]).collect{|p| p.patient_id}.uniq

    render :text => patients.to_json
  end

  def malaria(startdate = Time.now, enddate = Time.now, group = 1, field = "")
    patients = PatientReport.find(:all, :conditions => ["diagnosis = ? AND diagnosis_date >= ? AND diagnosis_date <= ?", 
        "Malaria", startdate, enddate]).collect{|p| p.patient_id}.uniq

    render :text => patients.to_json
  end

  def post_partum(startdate = Time.now, enddate = Time.now, group = 1, field = "")
    patients = PatientReport.find(:all, :conditions => ["diagnosis = ? AND diagnosis_date >= ? AND diagnosis_date <= ?", 
        "Post Partum", startdate, enddate]).collect{|p| p.patient_id}.uniq

    render :text => patients.to_json
  end

  def haemorrhage(startdate = Time.now, enddate = Time.now, group = 1, field = "")
    patients = PatientReport.find(:all, :conditions => ["diagnosis = ? AND diagnosis_date >= ? AND diagnosis_date <= ?", 
        "Haemorrhage", startdate, enddate]).collect{|p| p.patient_id}.uniq

    render :text => patients.to_json
  end

  def ante_partum(startdate = Time.now, enddate = Time.now, group = 1, field = "")
    patients = PatientReport.find(:all, :conditions => ["diagnosis LIKE ? AND diagnosis_date >= ? AND diagnosis_date <= ?", 
        "%Ante%Partum%", startdate, enddate]).collect{|p| p.patient_id}.uniq

    render :text => patients.to_json
  end

  def pre_eclampsia(startdate = Time.now, enddate = Time.now, group = 1, field = "")
    patients = PatientReport.find(:all, :conditions => ["diagnosis = ? AND diagnosis_date >= ? AND diagnosis_date <= ?", 
        "Pre-Eclampsia", startdate, enddate]).collect{|p| p.patient_id}.uniq

    render :text => patients.to_json
  end

  def eclampsia(startdate = Time.now, enddate = Time.now, group = 1, field = "")
    patients = PatientReport.find(:all, :conditions => ["diagnosis = ? AND diagnosis_date >= ? AND diagnosis_date <= ?",
        "Eclampsia", startdate, enddate]).collect{|p| p.patient_id}.uniq

    render :text => patients.to_json
  end

  def premature_labour(startdate = Time.now, enddate = Time.now, group = 1, field = "")
    patients = PatientReport.find(:all, :conditions => ["diagnosis = ? AND diagnosis_date >= ? AND diagnosis_date <= ?", 
        "Premature Labour", startdate, enddate]).collect{|p| p.patient_id}.uniq

    render :text => patients.to_json
  end

  def premature_membranes_rapture(startdate = Time.now, enddate = Time.now, group = 1, field = "")
    patients = PatientReport.find(:all, :conditions => ["diagnosis = ? AND diagnosis_date >= ? AND diagnosis_date <= ?", 
        "Premature Membranes Rapture", startdate, enddate]).collect{|p| p.patient_id}.uniq

    render :text => patients.to_json
  end

  def laparatomy(startdate = Time.now, enddate = Time.now, group = 1, field = "")
    patients = PatientReport.find(:all, :conditions => ["procedure_done LIKE ? AND procedure_date >= ? AND procedure_date <= ?", 
        "%Laparatomy%", startdate, enddate]).collect{|p| p.patient_id}.uniq

    render :text => patients.to_json
  end

  def ruptured_uterus(startdate = Time.now, enddate = Time.now, group = 1, field = "")
    patients = PatientReport.find(:all, :conditions => ["diagnosis = ? AND diagnosis_date >= ? AND diagnosis_date <= ?", 
        "Ruptured Uterus", startdate, enddate]).collect{|p| p.patient_id}.uniq

    render :text => patients.to_json
  end

  def diagnosis(startdate = Time.now, enddate = Time.now, group = 1, field = "")
	
    check_field = field.humanize.gsub("- ", "-").gsub("_", " ").gsub("!", "/")
    if check_field.downcase == "pprom"
      check_field = " Preterm Premature Rupture Of Membranes (Pprom)"
    end
    patients = PatientReport.find(:all, :conditions => ["diagnosis = ? AND diagnosis_date >= ? AND diagnosis_date <= ?", 
        check_field, startdate, enddate]).collect{|p| p.patient_id}.uniq
    if check_field == "anaemia"
      patients_like = PatientReport.find(:all, :conditions => ["diagnosis = ? AND diagnosis_date >= ? AND diagnosis_date <= ?",
          check_field, startdate, enddate]).collect{|p| p.patient_id}.uniq
    end
    render :text => patients.to_json
  end

  def diagnosis_regex(startdate = Time.now, enddate = Time.now, group = 1, field = "")

    check_field = field.humanize.gsub("- ", "-").gsub("_", " ").gsub("!", "/")
    if field == "invasive_cancer_of_cervix"
      patients = PatientReport.find(:all, :conditions => ["diagnosis IN (?) AND diagnosis_date >= ? AND diagnosis_date <= ?",
          ["Cervical stage 1", "Cervical stage 2", "Cervical stage 3", "Cervical stage 4", "Invasive cancer of cervix", "Cancer of Cervix"], 			startdate, enddate]).collect{|p| p.patient_id}.uniq
    else
      patients = PatientReport.find(:all, :conditions => ["diagnosis regexp ? AND diagnosis_date >= ? AND diagnosis_date <= ?",
          check_field, startdate, enddate]).collect{|p| p.patient_id}.uniq

      if check_field == "Anaemia"
        patients_like = PatientReport.find(:all, :conditions => ["diagnosis regexp ? AND diagnosis_date >= ? AND diagnosis_date <= ?",
            "anemia", startdate, enddate]).collect{|p| p.patient_id}.uniq
        patients = patients.concat(patients_like).uniq
      end
    end
	
    render :text => patients.to_json
  end

  def procedure(startdate = Time.now, enddate = Time.now, group = 1, field = "", proc = "")
    check_field = field.humanize.gsub("- ", "-").gsub("!", "/")

    if check_field.downcase == "intrauterine device"
      check_field = "Intrauterine Device (IUD)"
    end

    check_proc = proc.humanize.gsub("- ", "-").gsub("!", "/")
    if proc.downcase == "evacuation"
      check_proc = "Evacuation/Manual Vacuum Aspiration"
    end
	
    patients = PatientReport.find(:all, :conditions => ["diagnosis = ? AND procedure_done = ? AND diagnosis_date >= ? AND diagnosis_date <= ?",   check_field, check_proc, startdate, enddate]).collect{|p| p.patient_id}.uniq

    render :text => patients.to_json
  end

  def decompose
		@patients = Patient.find(:all, :conditions => ["patient_id IN (?)", params[:patients].split(",")]).uniq
		render :layout => false
  end

	
  def matrix_decompose
		@patients = Patient.find(:all, :conditions => ["patient_id IN (?)", params[:patients].split(",")]).uniq rescue [  ]

    if @patients.blank? && session[:drill_down_data].present? & params[:group].present?

      ids = []

      if session[:drill_down_data]["#{params[:group]}"].class.to_s.match(/Array/i)
        ids = session[:drill_down_data]["#{params[:group]}"]      
      elsif params[:key].present?
        ids = (session[:drill_down_data]["#{params[:group]}"]["#{params[:key].upcase.strip}"] +
            ((session[:drill_down_data]["#{params[:group]}"]["FE_#{params[:key].gsub(/male\_/i, '').upcase.strip}"] || []) rescue []) +
            ((session[:drill_down_data]["#{params[:group]}"]["F_#{params[:key].gsub(/male\_/i, '').upcase.strip}"] || []) rescue [])).uniq rescue []
      end
      @patients = Patient.find(:all, :conditions => ["patient_id IN (?)", ids]).uniq if ids.present?

    end
  
		render :layout => false
  end

	def baby_matrix	
		render :layout => false
	end
	
	def baby_matrix_printable			
		render :layout => false
	end
	
	def matrix_q
    case params[:field]
    when "lessorequal1499_macerated"
      lessorequal1499(params[:start_date].to_date, params[:end_date].to_date, 'Macerated Still birth')
    when "lessorequal1499_fresh"
      lessorequal1499(params[:start_date].to_date, params[:end_date].to_date, 'Fresh Still birth')
    when "lessorequal1499_predischarge"
      lessorequal1499_predischarge(params[:start_date].to_date, params[:end_date].to_date)
    when "lessorequal1499_aliveatdischarge"
      lessorequal1499_aliveatdischarge(params[:start_date].to_date, params[:end_date].to_date)
    when "lessorequal1499_missingoutcomes"
      lessorequal1499_missingoutcomes(params[:start_date].to_date, params[:end_date].to_date)
    when "lessorequal1499_total"
      lessorequal1499_total(params[:start_date].to_date, params[:end_date].to_date)
    when "1500-2499_macerated"
      from1500to2499(params[:start_date].to_date, params[:end_date].to_date, 'Macerated Still birth')
    when "1500-2499_fresh"
      from1500to2499(params[:start_date].to_date, params[:end_date].to_date, 'Fresh Still birth')
    when "1500-2499_predischarge"
      from1500to2499_predischarge(params[:start_date].to_date, params[:end_date].to_date)
    when "1500-2499_aliveatdischarge"
      from1500to2499_aliveatdischarge(params[:start_date].to_date, params[:end_date].to_date)
    when "1500-2499_missingoutcomes"
      from1500to2499_missingoutcomes(params[:start_date].to_date, params[:end_date].to_date)
    when "1500-2499_total"
      from1500to2499_total(params[:start_date].to_date, params[:end_date].to_date)
    when "greaterorequal2500_macerated"
      greaterorequal2500(params[:start_date].to_date, params[:end_date].to_date, 'Macerated Still birth')
    when "greaterorequal2500_fresh"
      greaterorequal2500(params[:start_date].to_date, params[:end_date].to_date, 'Fresh Still birth')
    when "greaterorequal2500_predischarge"
      greaterorequal2500_predischarge(params[:start_date].to_date, params[:end_date].to_date)
    when "greaterorequal2500_aliveatdischarge"
      greaterorequal2500_aliveatdischarge(params[:start_date].to_date, params[:end_date].to_date)
    when "greaterorequal2500_missingoutcomes"
      greaterorequal2500_missingoutcomes(params[:start_date].to_date, params[:end_date].to_date)
    when "greaterorequal2500_total"
      greaterorequal2500_total(params[:start_date].to_date, params[:end_date].to_date)
    when "missingweights_macerated"
      missingweights(params[:start_date].to_date, params[:end_date].to_date, 'Macerated Still birth')
    when "missingweights_fresh"
      missingweights(params[:start_date].to_date, params[:end_date].to_date, 'Fresh Still birth')
    when "missingweights_predischarge"
      missingweights_predischarge(params[:start_date].to_date, params[:end_date].to_date)
    when "missingweights_aliveatdischarge"
      missingweights_aliveatdischarge(params[:start_date].to_date, params[:end_date].to_date)
    when "missingweights_missingoutcomes"
      missingweights_missingoutcomes(params[:start_date].to_date, params[:end_date].to_date)
    when "missingweights_total"
      missingweights_total(params[:start_date].to_date, params[:end_date].to_date)
    when "total_macerated"
      total(params[:start_date].to_date, params[:end_date].to_date, 'Macerated Still birth')
    when "total_fresh"
      total(params[:start_date].to_date, params[:end_date].to_date, 'Fresh Still birth')
    when "total_predischarge"
      total_predischarge(params[:start_date].to_date, params[:end_date].to_date)
    when "total_aliveatdischarge"
      total_aliveatdischarge(params[:start_date].to_date, params[:end_date].to_date)
    when "total_missingoutcomes"
      total_missingoutcomes(params[:start_date].to_date, params[:end_date].to_date)
    when "total_total"
      total_total(params[:start_date].to_date, params[:end_date].to_date)
    end
  end
	
	def lessorequal1499(startdate = Time.now, enddate = Time.now, field = 'blank')
    babies = []

    @concepts = ['BABY OUTCOME'].collect{
      |val| ConceptName.find_by_name(val).concept_id
    }
    @concepts_coded = "'" + @concepts.join("','") + "'"

    Relationship.find_by_sql("SELECT r.person_b FROM relationship r JOIN obs o ON o.person_id = r.person_b
				WHERE r.voided = 0 AND r.relationship = (SELECT relationship_type_id FROM relationship_type WHERE a_is_to_b = 'Mother' AND b_is_to_a = 'Child')
				AND DATE_FORMAT((SELECT birthdate FROM person WHERE person_id = r.person_b), '%Y-%m-%d') <= '#{enddate}' 
				AND DATE_FORMAT((SELECT birthdate FROM person WHERE person_id = r.person_b), '%Y-%m-%d') >= '#{startdate}' 
				AND o.concept_id IN (#{@concepts_coded})
				AND o.voided = 0
				AND o.value_coded = (SELECT concept_id FROM concept_name WHERE name = '#{field}' LIMIT 1)").each do |data| 

      weight = Observation.find(:last,
        :conditions => ["person_id = ? AND concept_id = ?",
          data.person_b, ConceptName.find_by_name("BIRTH WEIGHT").concept_id]).answer_string.to_i  rescue nil

      babies << data.person_b if weight and (weight <= 1499)
    end

    babies.delete_if{|baby| baby.blank?}
    render :text => babies.uniq.to_json
	end

  def lessorequal1499_neonatal(startdate = Time.now, enddate = Time.now)
    babies = []

    @values = ['Neonatal death'].collect{
      |val| ConceptName.find_by_name(val).concept_id
    }
    @values_coded = "'" + @values.join("','") + "'"

    @concepts = ['BABY OUTCOME'].collect{
      |val| ConceptName.find_by_name(val).concept_id
    }

    @concepts_coded = "'" + @concepts.join("','") + "'"

    Relationship.find_by_sql("SELECT r.person_b FROM relationship r JOIN obs o ON o.person_id = r.person_b
				WHERE r.voided = 0 AND r.relationship = (SELECT relationship_type_id FROM relationship_type WHERE a_is_to_b = 'Mother' AND b_is_to_a = 'Child')
				AND DATE_FORMAT((SELECT birthdate FROM person WHERE person_id = r.person_b), '%Y-%m-%d') <= '#{enddate}'
				AND DATE_FORMAT((SELECT birthdate FROM person WHERE person_id = r.person_b), '%Y-%m-%d') >= '#{startdate}'
				AND o.concept_id IN (#{@concepts_coded})
				AND o.voided = 0
				AND (o.value_coded IN (#{@values_coded}) OR o.value_text IN ('Dead'))").each do |data|


      weight = Observation.find(:last,
        :conditions => ["person_id = ? AND concept_id = ?",
          data.person_b, ConceptName.find_by_name("BIRTH WEIGHT").concept_id]).answer_string.to_i  rescue nil

      babies << data.person_b if weight  and (weight <= 1499)
    end

    babies.delete_if{|baby|
      baby.blank? or (Observation.find(:last, :conditions => ["person_id = ? AND concept_id = ?",
            baby, ConceptName.find_by_name("BABY OUTCOME").concept_id]).answer_string.blank? rescue false)
    }

    babies
	end

	def lessorequal1499_predischarge(startdate = Time.now, enddate = Time.now)
    babies = []

    @values = ['Dead'].collect{
      |val| ConceptName.find_by_name(val).concept_id
    }
    @values_coded = "'" + @values.join("','") + "'"

    @concepts = ['STATUS OF BABY'].collect{
      |val| ConceptName.find_by_name(val).concept_id
    }

    @concepts_coded = "'" + @concepts.join("','") + "'"

    Relationship.find_by_sql("SELECT r.person_b FROM relationship r JOIN obs o ON o.person_id = r.person_b
				WHERE r.voided = 0 AND r.relationship = (SELECT relationship_type_id FROM relationship_type WHERE a_is_to_b = 'Mother' AND b_is_to_a = 'Child')
				AND DATE_FORMAT((SELECT birthdate FROM person WHERE person_id = r.person_b), '%Y-%m-%d') <= '#{enddate}' 
				AND DATE_FORMAT((SELECT birthdate FROM person WHERE person_id = r.person_b), '%Y-%m-%d') >= '#{startdate}' 
				AND o.concept_id IN (#{@concepts_coded})
				AND o.voided = 0
				AND (o.value_coded IN (#{@values_coded}) OR o.value_text IN ('Dead'))").each do |data|


      weight = Observation.find(:last,
        :conditions => ["person_id = ? AND concept_id = ?",
          data.person_b, ConceptName.find_by_name("BIRTH WEIGHT").concept_id]).answer_string.to_i  rescue nil

      babies << data.person_b if weight  and (weight <= 1499)
    end
				
    babies.delete_if{|baby|
      baby.blank? or (Observation.find(:last, :conditions => ["person_id = ? AND concept_id = ?",
            baby, ConceptName.find_by_name("STATUS OF BABY").concept_id]).answer_string.blank? rescue false)
    }
        
    neo = lessorequal1499_neonatal(startdate, enddate) rescue []
    babies = babies.concat(neo)
        
    render :text => babies.uniq.to_json
	end

	def lessorequal1499_aliveatdischarge(startdate = Time.now, enddate = Time.now)
    babies = []
			
    Relationship.find_by_sql("SELECT r.person_b FROM relationship r JOIN obs o ON o.person_id = r.person_b
				WHERE r.voided = 0 AND r.relationship = (SELECT relationship_type_id FROM relationship_type WHERE a_is_to_b = 'Mother' AND b_is_to_a = 'Child')
				AND DATE_FORMAT((SELECT birthdate FROM person WHERE person_id = r.person_b), '%Y-%m-%d') <= '#{enddate}' 
				AND DATE_FORMAT((SELECT birthdate FROM person WHERE person_id = r.person_b), '%Y-%m-%d') >= '#{startdate}' 
				AND o.concept_id = (SELECT concept_id FROM concept_name WHERE name = 'STATUS OF BABY')
				AND o.voided = 0
				AND o.value_coded = (SELECT concept_id FROM concept_name WHERE name = 'Alive' LIMIT 1)").each do |data| 

      weight = Observation.find(:last,
        :conditions => ["person_id = ? AND concept_id = ?",
          data.person_b, ConceptName.find_by_name("BIRTH WEIGHT").concept_id]).answer_string.to_i  rescue nil

      babies << data.person_b if weight and (weight <= 1499)
    end

    babies.delete_if{|baby|
      baby.blank? or (Observation.find(:last, :conditions => ["person_id = ? AND concept_id = ?",
            baby, ConceptName.find_by_name("STATUS OF BABY").concept_id]).answer_string.blank? rescue false)
    }
    render :text => babies.uniq.to_json
	end

  def lessorequal1499_alive_predischarge(startdate = Time.now, enddate = Time.now)
    babies = []
    Relationship.find_by_sql("SELECT r.person_b FROM relationship r JOIN obs o ON o.person_id = r.person_b
				WHERE r.voided = 0 AND r.relationship = (SELECT relationship_type_id FROM relationship_type WHERE a_is_to_b = 'Mother' AND b_is_to_a = 'Child')
				AND DATE_FORMAT((SELECT birthdate FROM person WHERE person_id = r.person_b), '%Y-%m-%d') <= '#{enddate}'
				AND DATE_FORMAT((SELECT birthdate FROM person WHERE person_id = r.person_b), '%Y-%m-%d') >= '#{startdate}'
				AND o.concept_id = (SELECT concept_id FROM concept_name WHERE name = 'BABY OUTCOME')
				AND o.voided = 0
        AND (SELECT COUNT(*) FROM obs WHERE person_id = r.person_b AND voided = 0
            AND concept_id = (SELECT concept_id FROM concept_name WHERE name = 'STATUS OF BABY' LIMIT 1)) = 0
				AND o.value_coded IN (SELECT concept_id FROM concept_name WHERE name = 'Alive')").each do |data|

      weight = Observation.find(:last,
        :conditions => ["person_id = ? AND concept_id = ?",
          data.person_b, ConceptName.find_by_name("BIRTH WEIGHT").concept_id]).answer_string.to_i  rescue nil

      babies << data.person_b if weight and (weight <= 1499)
    end

    babies.delete_if{|baby| baby.blank? }
    babies
	end
  
  def lessorequal1499_missingoutcomes(startdate = Time.now, enddate = Time.now)
    babies = []

    @values = ['Neonatal death', 'Fresh still birth', 'Macerated still birth', 'Intrauterine death', 'Alive'].collect{
      |val| ConceptName.find_by_name(val).concept_id
    }
    @values_coded = "'" + @values.join("','") + "'"

    @concepts = ['BABY OUTCOME'].collect{
      |val| ConceptName.find_by_name(val).concept_id
    }
    @concepts_coded = "'" + @concepts.join("','") + "'"

    Relationship.find_by_sql("SELECT r.person_b FROM relationship r JOIN obs o ON o.person_id = r.person_b
				WHERE r.voided = 0 AND r.relationship = (SELECT relationship_type_id FROM relationship_type WHERE a_is_to_b = 'Mother' AND b_is_to_a = 'Child')
				AND DATE_FORMAT((SELECT birthdate FROM person WHERE person_id = r.person_b), '%Y-%m-%d') <= '#{enddate}' 
				AND DATE_FORMAT((SELECT birthdate FROM person WHERE person_id = r.person_b), '%Y-%m-%d') >= '#{startdate}' 
				AND o.concept_id IN (#{@concepts_coded})
				AND o.voided = 0
				AND (o.value_coded NOT IN (#{@values_coded})  								
								OR (SELECT COUNT(*) FROM obs WHERE person_id = r.person_b AND concept_id = (SELECT concept_id FROM concept_name WHERE name = 'BABY OUTCOME')) = 0
	)").each do |data| 
				
      weight = Observation.find(:last,
        :conditions => ["person_id = ? AND concept_id = ?",
          data.person_b, ConceptName.find_by_name("BIRTH WEIGHT").concept_id]).answer_string.to_i  rescue nil

      babies << data.person_b if weight and (weight <= 1499)
    end

    babies.delete_if{|baby|
      baby.blank? or (Observation.find(:last, :conditions => ["person_id = ? AND concept_id = ?",
            baby, ConceptName.find_by_name("STATUS OF BABY").concept_id]).answer_string.blank? rescue false)
    }
    render :text => babies.uniq.to_json
  end

  def lessorequal1499_total(startdate = Time.now, enddate = Time.now)
    babies = []

    @values = ['Neonatal death', 'Fresh still birth', 'Macerated still birth', 'Intrauterine death', 'Alive'].collect{
      |val| ConceptName.find_by_name(val).concept_id
    }
    @values_coded = "'" + @values.join("','") + "'"

    @concepts = ['BABY OUTCOME', 'STATUS OF BABY'].collect{
      |val| ConceptName.find_by_name(val).concept_id
    }
    @concepts_coded = "'" + @concepts.join("','") + "'"

    Relationship.find_by_sql("SELECT r.person_b FROM relationship r JOIN obs o ON o.person_id = r.person_b
				WHERE r.voided = 0 AND r.relationship = (SELECT relationship_type_id FROM relationship_type WHERE a_is_to_b = 'Mother' AND b_is_to_a = 'Child')
				AND DATE_FORMAT((SELECT birthdate FROM person WHERE person_id = r.person_b), '%Y-%m-%d') <= '#{enddate}' 
				AND DATE_FORMAT((SELECT birthdate FROM person WHERE person_id = r.person_b), '%Y-%m-%d') >= '#{startdate}' 
				AND o.voided = 0
				AND o.concept_id IN (#{@concepts_coded})").each do |data| 

      weight = Observation.find(:last,
        :conditions => ["person_id = ? AND concept_id = ?",
          data.person_b, ConceptName.find_by_name("BIRTH WEIGHT").concept_id]).answer_string.to_i  rescue nil
      babies << data.person_b if weight and (weight <= 1499)
    end

    alive_without_discharge = lessorequal1499_alive_predischarge(startdate, enddate) rescue []
   
    babies.delete_if{|baby|
      baby.blank? or (Observation.find(:last, :conditions => ["person_id = ? AND concept_id = ?",
            baby, ConceptName.find_by_name("STATUS OF BABY").concept_id]).answer_string.blank? rescue false)
    }
    babies = babies - alive_without_discharge
    render :text => babies.uniq.to_json
  end

  def from1500to2499(startdate = Time.now, enddate = Time.now, field = 'blank')
    babies = []

    @concepts = ['BABY OUTCOME', 'STATUS OF BABY'].collect{
      |val| ConceptName.find_by_name(val).concept_id
    }
    @concepts_coded = "'" + @concepts.join("','") + "'"

    Relationship.find_by_sql("SELECT r.person_b FROM relationship r JOIN obs o ON o.person_id = r.person_b
				WHERE r.voided = 0 AND r.relationship = (SELECT relationship_type_id FROM relationship_type WHERE a_is_to_b = 'Mother' AND b_is_to_a = 'Child')
				AND DATE_FORMAT((SELECT birthdate FROM person WHERE person_id = r.person_b), '%Y-%m-%d') <= '#{enddate}' 
				AND DATE_FORMAT((SELECT birthdate FROM person WHERE person_id = r.person_b), '%Y-%m-%d') >= '#{startdate}' 
				AND o.concept_id IN (#{@concepts_coded})
				AND o.voided = 0
				AND o.value_coded = (SELECT concept_id FROM concept_name WHERE name = '#{field}' LIMIT 1)").each do |data| 

      weight = Observation.find(:last,
        :conditions => ["person_id = ? AND concept_id = ?",
          data.person_b, ConceptName.find_by_name("BIRTH WEIGHT").concept_id]).answer_string.to_i  rescue nil

      babies << data.person_b if weight and (weight > 1499) and (weight <= 2499)
    end

    babies.delete_if{|baby| baby.blank?}
    render :text => babies.uniq.to_json
  end

  def from1500to2499_neonatal(startdate = Time.now, enddate = Time.now)
    babies = []

    @values = ['Neonatal death'].collect{
      |val| ConceptName.find_by_name(val).concept_id
    }
    @values_coded = "'" + @values.join("','") + "'"

    @concepts = ['BABY OUTCOME'].collect{
      |val| ConceptName.find_by_name(val).concept_id
    }

    @concepts_coded = "'" + @concepts.join("','") + "'"

    Relationship.find_by_sql("SELECT r.person_b FROM relationship r JOIN obs o ON o.person_id = r.person_b
				WHERE r.voided = 0 AND r.relationship = (SELECT relationship_type_id FROM relationship_type WHERE a_is_to_b = 'Mother' AND b_is_to_a = 'Child')
				AND DATE_FORMAT((SELECT birthdate FROM person WHERE person_id = r.person_b), '%Y-%m-%d') <= '#{enddate}'
				AND DATE_FORMAT((SELECT birthdate FROM person WHERE person_id = r.person_b), '%Y-%m-%d') >= '#{startdate}'
				AND o.concept_id IN (#{@concepts_coded})
				AND o.voided = 0
				AND (o.value_coded IN (#{@values_coded}) OR o.value_text IN ('Dead'))").each do |data|


      weight = Observation.find(:last,
        :conditions => ["person_id = ? AND concept_id = ?",
          data.person_b, ConceptName.find_by_name("BIRTH WEIGHT").concept_id]).answer_string.to_i  rescue nil

      babies << data.person_b if weight and (weight > 1499) and (weight <= 2499)
    end

    babies.delete_if{|baby|
      baby.blank? or (Observation.find(:last, :conditions => ["person_id = ? AND concept_id = ?",
            baby, ConceptName.find_by_name("BABY OUTCOME").concept_id]).answer_string.blank? rescue false)
    }

    babies
  end

  def from1500to2499_predischarge(startdate = Time.now, enddate = Time.now)
    babies = []

    @values = ['Dead'].collect{
      |val| ConceptName.find_by_name(val).concept_id
    }
    @values_coded = "'" + @values.join("','") + "'"

    @concepts = ['STATUS OF BABY'].collect{
      |val| ConceptName.find_by_name(val).concept_id
    }
    @concepts_coded = "'" + @concepts.join("','") + "'"

    Relationship.find_by_sql("SELECT r.person_b FROM relationship r JOIN obs o ON o.person_id = r.person_b
				WHERE r.voided = 0 AND r.relationship = (SELECT relationship_type_id FROM relationship_type WHERE a_is_to_b = 'Mother' AND b_is_to_a = 'Child')
				AND DATE_FORMAT((SELECT birthdate FROM person WHERE person_id = r.person_b), '%Y-%m-%d') <= '#{enddate}' 
				AND DATE_FORMAT((SELECT birthdate FROM person WHERE person_id = r.person_b), '%Y-%m-%d') >= '#{startdate}' 
				AND o.concept_id IN (#{@concepts_coded})
				AND o.voided = 0
				AND (o.value_coded IN (#{@values_coded}) OR o.value_text IN ('Dead'))").each do |data|

      weight = Observation.find(:last,
        :conditions => ["person_id = ? AND concept_id = ?",
          data.person_b, ConceptName.find_by_name("BIRTH WEIGHT").concept_id]).answer_string.to_i  rescue nil

      babies << data.person_b if weight and (weight > 1499) and (weight <= 2499)
    end
				
    babies.delete_if{|baby|
      baby.blank? or (Observation.find(:last, :conditions => ["person_id = ? AND concept_id = ?",
            baby, ConceptName.find_by_name("STATUS OF BABY").concept_id]).answer_string.blank? rescue false)
    }
    neo = from1500to2499_neonatal(startdate, enddate)
    babies = babies.concat(neo)
    render :text => babies.uniq.to_json
  end

  def from1500to2499_alive_predischarge(startdate = Time.now, enddate = Time.now)
    babies = []
    Relationship.find_by_sql("SELECT r.person_b FROM relationship r JOIN obs o ON o.person_id = r.person_b
				WHERE r.voided = 0 AND r.relationship = (SELECT relationship_type_id FROM relationship_type WHERE a_is_to_b = 'Mother' AND b_is_to_a = 'Child')
				AND DATE_FORMAT((SELECT birthdate FROM person WHERE person_id = r.person_b), '%Y-%m-%d') <= '#{enddate}'
				AND DATE_FORMAT((SELECT birthdate FROM person WHERE person_id = r.person_b), '%Y-%m-%d') >= '#{startdate}'
				AND o.concept_id = (SELECT concept_id FROM concept_name WHERE name = 'BABY OUTCOME')
				AND o.voided = 0
        AND (SELECT COUNT(*) FROM obs WHERE person_id = r.person_b AND voided = 0
            AND concept_id = (SELECT concept_id FROM concept_name WHERE name = 'STATUS OF BABY' LIMIT 1)) = 0
				AND o.value_coded IN (SELECT concept_id FROM concept_name WHERE name = 'Alive')").each do |data|

      weight = Observation.find(:last,
        :conditions => ["person_id = ? AND concept_id = ?",
          data.person_b, ConceptName.find_by_name("BIRTH WEIGHT").concept_id]).answer_string.to_i  rescue nil

      babies << data.person_b if weight and (weight > 1499) and (weight <= 2499)
    end

    babies.delete_if{|baby| baby.blank? }
    babies
	end
  
  def from1500to2499_aliveatdischarge(startdate = Time.now, enddate = Time.now)
    babies = []
			
    Relationship.find_by_sql("SELECT r.person_b FROM relationship r JOIN obs o ON o.person_id = r.person_b
				WHERE r.voided = 0 AND r.relationship = (SELECT relationship_type_id FROM relationship_type WHERE a_is_to_b = 'Mother' AND b_is_to_a = 'Child')
				AND DATE_FORMAT((SELECT birthdate FROM person WHERE person_id = r.person_b), '%Y-%m-%d') <= '#{enddate}' 
				AND DATE_FORMAT((SELECT birthdate FROM person WHERE person_id = r.person_b), '%Y-%m-%d') >= '#{startdate}' 
				AND o.concept_id = (SELECT concept_id FROM concept_name WHERE name = 'STATUS OF BABY')
				AND o.voided = 0
				AND o.value_coded = (SELECT concept_id FROM concept_name WHERE name = 'Alive' LIMIT 1)").each do |data| 

      weight = Observation.find(:last,
        :conditions => ["person_id = ? AND concept_id = ?",
          data.person_b, ConceptName.find_by_name("BIRTH WEIGHT").concept_id]).answer_string.to_i  rescue nil

      babies << data.person_b if weight and (weight > 1499) and (weight <= 2499)
    end

    babies.delete_if{|baby|
      baby.blank? or (Observation.find(:last, :conditions => ["person_id = ? AND concept_id = ?",
            baby, ConceptName.find_by_name("STATUS OF BABY").concept_id]).answer_string.blank? rescue false)
    }
    render :text => babies.uniq.to_json
  end

  def from1500to2499_missingoutcomes(startdate = Time.now, enddate = Time.now)
    babies = []

    @values = ['Neonatal death', 'Fresh still birth', 'Macerated still birth', 'Intrauterine death', 'Alive'].collect{
      |val| ConceptName.find_by_name(val).concept_id
    }
    @values_coded = "'" + @values.join("','") + "'"

    @concepts = ['BABY OUTCOME'].collect{
      |val| ConceptName.find_by_name(val).concept_id
    }
    @concepts_coded = "'" + @concepts.join("','") + "'"

    Relationship.find_by_sql("SELECT r.person_b FROM relationship r JOIN obs o ON o.person_id = r.person_b
				WHERE r.voided = 0 AND r.relationship = (SELECT relationship_type_id FROM relationship_type WHERE a_is_to_b = 'Mother' AND b_is_to_a = 'Child')
				AND DATE_FORMAT((SELECT birthdate FROM person WHERE person_id = r.person_b), '%Y-%m-%d') <= '#{enddate}' 
				AND DATE_FORMAT((SELECT birthdate FROM person WHERE person_id = r.person_b), '%Y-%m-%d') >= '#{startdate}' 
				AND o.concept_id IN (#{@concepts_coded})
				AND o.voided = 0
				AND (o.value_coded NOT IN (#{@values_coded})  								
								OR (SELECT COUNT(*) FROM obs WHERE person_id = r.person_b AND concept_id = (SELECT concept_id FROM concept_name WHERE name = 'BABY OUTCOME')) = 0
	)").each do |data| 

      weight = Observation.find(:last,
        :conditions => ["person_id = ? AND concept_id = ?",
          data.person_b, ConceptName.find_by_name("BIRTH WEIGHT").concept_id]).answer_string.to_i  rescue nil

      babies << data.person_b if weight and (weight > 1499) and (weight <= 2499)
    end

    babies.delete_if{|baby|
      baby.blank? or (Observation.find(:last, :conditions => ["person_id = ? AND concept_id = ?",
            baby, ConceptName.find_by_name("STATUS OF BABY").concept_id]).answer_string.blank? rescue false)
    }
    render :text => babies.uniq.to_json
  end

  def from1500to2499_total(startdate = Time.now, enddate = Time.now)
    babies = []

    @values = ['Neonatal death', 'Fresh still birth', 'Macerated still birth', 'Intrauterine death', 'Alive'].collect{
      |val| ConceptName.find_by_name(val).concept_id
    }
    @values_coded = "'" + @values.join("','") + "'"

    @concepts = ['BABY OUTCOME', 'STATUS OF BABY'].collect{
      |val| ConceptName.find_by_name(val).concept_id
    }
    @concepts_coded = "'" + @concepts.join("','") + "'"

    Relationship.find_by_sql("SELECT r.person_b FROM relationship r JOIN obs o ON o.person_id = r.person_b
				WHERE r.voided = 0 AND r.relationship = (SELECT relationship_type_id FROM relationship_type WHERE a_is_to_b = 'Mother' AND b_is_to_a = 'Child')
				AND DATE_FORMAT((SELECT birthdate FROM person WHERE person_id = r.person_b), '%Y-%m-%d') <= '#{enddate}' 
				AND DATE_FORMAT((SELECT birthdate FROM person WHERE person_id = r.person_b), '%Y-%m-%d') >= '#{startdate}' 
				AND o.voided = 0
				AND o.concept_id IN (#{@concepts_coded})").each do |data| 

      weight = Observation.find(:last,
        :conditions => ["person_id = ? AND concept_id = ?",
          data.person_b, ConceptName.find_by_name("BIRTH WEIGHT").concept_id]).answer_string.to_i  rescue nil

      babies << data.person_b if weight and (weight > 1499) and (weight <= 2499)
    end

    alive_without_discharge = from1500to2499_alive_predischarge(startdate, enddate) rescue []
    babies = babies - alive_without_discharge

    babies.delete_if{|baby|
      baby.blank? or (Observation.find(:last, :conditions => ["person_id = ? AND concept_id = ?",
            baby, ConceptName.find_by_name("STATUS OF BABY").concept_id]).answer_string.blank? rescue false)
    }
    render :text => babies.uniq.to_json
  end
	
  def greaterorequal2500(startdate = Time.now, enddate = Time.now, field = 'blank')
    babies = []

    @concepts = ['BABY OUTCOME', 'STATUS OF BABY'].collect{
      |val| ConceptName.find_by_name(val).concept_id
    }
    @concepts_coded = "'" + @concepts.join("','") + "'"

    Relationship.find_by_sql("SELECT r.person_b FROM relationship r JOIN obs o ON o.person_id = r.person_b
				WHERE r.voided = 0 AND r.relationship = (SELECT relationship_type_id FROM relationship_type WHERE a_is_to_b = 'Mother' AND b_is_to_a = 'Child')
				AND DATE_FORMAT((SELECT birthdate FROM person WHERE person_id = r.person_b), '%Y-%m-%d') <= '#{enddate}' 
				AND DATE_FORMAT((SELECT birthdate FROM person WHERE person_id = r.person_b), '%Y-%m-%d') >= '#{startdate}' 
				AND o.concept_id IN (#{@concepts_coded})
				AND o.voided = 0
				AND o.value_coded = (SELECT concept_id FROM concept_name WHERE name = '#{field}' LIMIT 1)").each do |data| 

      weight = Observation.find(:last,
        :conditions => ["person_id = ? AND concept_id = ?",
          data.person_b, ConceptName.find_by_name("BIRTH WEIGHT").concept_id]).answer_string.to_i  rescue nil

      babies << data.person_b if weight and (weight > 2499)
    end

    babies.delete_if{|baby| baby.blank?}
    render :text => babies.uniq.to_json
  end

  def greaterorequal2500_neonatal(startdate = Time.now, enddate = Time.now)
    babies = []

    @values = ['Neonatal death'].collect{
      |val| ConceptName.find_by_name(val).concept_id
    }
    @values_coded = "'" + @values.join("','") + "'"

    @concepts = ['BABY OUTCOME'].collect{
      |val| ConceptName.find_by_name(val).concept_id
    }

    @concepts_coded = "'" + @concepts.join("','") + "'"

    Relationship.find_by_sql("SELECT r.person_b FROM relationship r JOIN obs o ON o.person_id = r.person_b
				WHERE r.voided = 0 AND r.relationship = (SELECT relationship_type_id FROM relationship_type WHERE a_is_to_b = 'Mother' AND b_is_to_a = 'Child')
				AND DATE_FORMAT((SELECT birthdate FROM person WHERE person_id = r.person_b), '%Y-%m-%d') <= '#{enddate}'
				AND DATE_FORMAT((SELECT birthdate FROM person WHERE person_id = r.person_b), '%Y-%m-%d') >= '#{startdate}'
				AND o.concept_id IN (#{@concepts_coded})
				AND o.voided = 0
				AND (o.value_coded IN (#{@values_coded}) OR o.value_text IN ('Dead'))").each do |data|


      weight = Observation.find(:last,
        :conditions => ["person_id = ? AND concept_id = ?",
          data.person_b, ConceptName.find_by_name("BIRTH WEIGHT").concept_id]).answer_string.to_i  rescue nil

      babies << data.person_b if weight and (weight > 2499)
    end

    babies.delete_if{|baby|
      baby.blank? or (Observation.find(:last, :conditions => ["person_id = ? AND concept_id = ?",
            baby, ConceptName.find_by_name("BABY OUTCOME").concept_id]).answer_string.blank? rescue false)
    }

    babies
  end

  def greaterorequal2500_predischarge(startdate = Time.now, enddate = Time.now)
    babies = []

    @values = ['Dead'].collect{
      |val| ConceptName.find_by_name(val).concept_id
    }
    @values_coded = "'" + @values.join("','") + "'"

    @concepts = ['STATUS OF BABY'].collect{
      |val| ConceptName.find_by_name(val).concept_id
    }
    @concepts_coded = "'" + @concepts.join("','") + "'"

    Relationship.find_by_sql("SELECT r.person_b FROM relationship r JOIN obs o ON o.person_id = r.person_b
				WHERE r.voided = 0 AND r.relationship = (SELECT relationship_type_id FROM relationship_type WHERE a_is_to_b = 'Mother' AND b_is_to_a = 'Child')
				AND DATE_FORMAT((SELECT birthdate FROM person WHERE person_id = r.person_b), '%Y-%m-%d') <= '#{enddate}' 
				AND DATE_FORMAT((SELECT birthdate FROM person WHERE person_id = r.person_b), '%Y-%m-%d') >= '#{startdate}' 
				AND o.concept_id IN (#{@concepts_coded})
				AND o.voided = 0
				AND (o.value_coded IN (#{@values_coded}) OR o.value_text IN ('Dead'))").each do |data|


      weight = Observation.find(:last,
        :conditions => ["person_id = ? AND concept_id = ?",
          data.person_b, ConceptName.find_by_name("BIRTH WEIGHT").concept_id]).answer_string.to_i  rescue nil

      babies << data.person_b if weight and (weight > 2499)
    end
				
    babies.delete_if{|baby|
      baby.blank? or (Observation.find(:last, :conditions => ["person_id = ? AND concept_id = ?",
            baby, ConceptName.find_by_name("STATUS OF BABY").concept_id]).answer_string.blank? rescue false)
    }
        
    neo = greaterorequal2500_neonatal(startdate, enddate)
    babies = babies.concat(neo)
    render :text => babies.uniq.to_json
  end

  def greaterorequal2500_aliveatdischarge(startdate = Time.now, enddate = Time.now)
    babies = []
			
    Relationship.find_by_sql("SELECT r.person_b FROM relationship r JOIN obs o ON o.person_id = r.person_b
				WHERE r.voided = 0 AND r.relationship = (SELECT relationship_type_id FROM relationship_type WHERE a_is_to_b = 'Mother' AND b_is_to_a = 'Child')
				AND DATE_FORMAT((SELECT birthdate FROM person WHERE person_id = r.person_b), '%Y-%m-%d') <= '#{enddate}' 
				AND DATE_FORMAT((SELECT birthdate FROM person WHERE person_id = r.person_b), '%Y-%m-%d') >= '#{startdate}' 
				AND o.concept_id = (SELECT concept_id FROM concept_name WHERE name = 'STATUS OF BABY')
				AND o.voided = 0
				AND o.value_coded = (SELECT concept_id FROM concept_name WHERE name = 'Alive' LIMIT 1)").each do |data| 

      weight = Observation.find(:last,
        :conditions => ["person_id = ? AND concept_id = ?",
          data.person_b, ConceptName.find_by_name("BIRTH WEIGHT").concept_id]).answer_string.to_i  rescue nil

      babies << data.person_b if weight and (weight > 2499)
    end

    babies.delete_if{|baby|
      baby.blank? or (Observation.find(:last, :conditions => ["person_id = ? AND concept_id = ?",
            baby, ConceptName.find_by_name("STATUS OF BABY").concept_id]).answer_string.blank? rescue false)
    }
    render :text => babies.uniq.to_json
  end

  def greaterorequal2500_missingoutcomes(startdate = Time.now, enddate = Time.now)
    babies = []

    @values = ['Neonatal death', 'Fresh still birth', 'Macerated still birth', 'Intrauterine death', 'Alive'].collect{
      |val| ConceptName.find_by_name(val).concept_id
    }
    @values_coded = "'" + @values.join("','") + "'"

    @concepts = ['BABY OUTCOME'].collect{
      |val| ConceptName.find_by_name(val).concept_id
    }
    @concepts_coded = "'" + @concepts.join("','") + "'"

    Relationship.find_by_sql("SELECT r.person_b FROM relationship r JOIN obs o ON o.person_id = r.person_b
				WHERE r.voided = 0 AND r.relationship = (SELECT relationship_type_id FROM relationship_type WHERE a_is_to_b = 'Mother' AND b_is_to_a = 'Child')
				AND DATE_FORMAT((SELECT birthdate FROM person WHERE person_id = r.person_b), '%Y-%m-%d') <= '#{enddate}' 
				AND DATE_FORMAT((SELECT birthdate FROM person WHERE person_id = r.person_b), '%Y-%m-%d') >= '#{startdate}' 
				AND o.concept_id IN (#{@concepts_coded})
				AND o.voided = 0
				AND (o.value_coded NOT IN (#{@values_coded})  								
								OR (SELECT COUNT(*) FROM obs WHERE person_id = r.person_b AND concept_id = (SELECT concept_id FROM concept_name WHERE name = 'BABY OUTCOME')) = 0
	)").each do |data|  

      weight = Observation.find(:last,
        :conditions => ["person_id = ? AND concept_id = ?",
          data.person_b, ConceptName.find_by_name("BIRTH WEIGHT").concept_id]).answer_string.to_i  rescue nil

      babies << data.person_b if weight and (weight > 2499)
    end

    babies.delete_if{|baby|
      baby.blank? or (Observation.find(:last, :conditions => ["person_id = ? AND concept_id = ?",
            baby, ConceptName.find_by_name("STATUS OF BABY").concept_id]).answer_string.blank? rescue false)
    }
    render :text => babies.uniq.to_json
  end

  def greaterorequal2500_alive_predischarge(startdate = Time.now, enddate = Time.now)
    babies = []
    Relationship.find_by_sql("SELECT r.person_b FROM relationship r JOIN obs o ON o.person_id = r.person_b
				WHERE r.voided = 0 AND r.relationship = (SELECT relationship_type_id FROM relationship_type WHERE a_is_to_b = 'Mother' AND b_is_to_a = 'Child')
				AND DATE_FORMAT((SELECT birthdate FROM person WHERE person_id = r.person_b), '%Y-%m-%d') <= '#{enddate}'
				AND DATE_FORMAT((SELECT birthdate FROM person WHERE person_id = r.person_b), '%Y-%m-%d') >= '#{startdate}'
				AND o.concept_id = (SELECT concept_id FROM concept_name WHERE name = 'BABY OUTCOME')
				AND o.voided = 0
        AND (SELECT COUNT(*) FROM obs WHERE person_id = r.person_b AND voided = 0
            AND concept_id = (SELECT concept_id FROM concept_name WHERE name = 'STATUS OF BABY' LIMIT 1)) = 0
				AND o.value_coded IN (SELECT concept_id FROM concept_name WHERE name = 'Alive')").each do |data|

      weight = Observation.find(:last,
        :conditions => ["person_id = ? AND concept_id = ?",
          data.person_b, ConceptName.find_by_name("BIRTH WEIGHT").concept_id]).answer_string.to_i  rescue nil
      babies << data.person_b if weight and (weight >= 2500)
    end

    babies.delete_if{|baby| baby.blank? }
    babies
	end
  
  def greaterorequal2500_total(startdate = Time.now, enddate = Time.now)
    babies = []

    @values = ['Neonatal death', 'Fresh still birth', 'Macerated still birth', 'Intrauterine death', 'Alive'].collect{
      |val| ConceptName.find_by_name(val).concept_id
    }
    @values_coded = "'" + @values.join("','") + "'"
      

    @concepts = ['BABY OUTCOME', 'STATUS OF BABY'].collect{
      |val| ConceptName.find_by_name(val).concept_id
    }
    @concepts_coded = "'" + @concepts.join("','") + "'"

    Relationship.find_by_sql("SELECT r.person_b FROM relationship r JOIN obs o ON o.person_id = r.person_b
				WHERE r.voided = 0 AND r.relationship = (SELECT relationship_type_id FROM relationship_type WHERE a_is_to_b = 'Mother' AND b_is_to_a = 'Child')
				AND DATE_FORMAT((SELECT birthdate FROM person WHERE person_id = r.person_b), '%Y-%m-%d') <= '#{enddate}' 
				AND DATE_FORMAT((SELECT birthdate FROM person WHERE person_id = r.person_b), '%Y-%m-%d') >= '#{startdate}' 
				AND o.voided = 0       
				AND o.concept_id IN (#{@concepts_coded})").each do |data| 

      weight = Observation.find(:last,
        :conditions => ["person_id = ? AND concept_id = ?",
          data.person_b, ConceptName.find_by_name("BIRTH WEIGHT").concept_id]).answer_string.to_i  rescue nil

      babies << data.person_b if weight and (weight > 2499)
    end

    alive_without_discharge = greaterorequal2500_alive_predischarge(startdate, enddate) rescue []
    babies = babies - alive_without_discharge
    
    babies.delete_if{|baby|
      baby.blank? or (Observation.find(:last, :conditions => ["person_id = ? AND concept_id = ?",
            baby, ConceptName.find_by_name("STATUS OF BABY").concept_id]).answer_string.blank? rescue false)
    }
    render :text => babies.uniq.to_json
  end

  def missingweights(startdate = Time.now, enddate = Time.now, field = 'blank')
    babies = []

    @concepts = ['BABY OUTCOME', 'STATUS OF BABY'].collect{
      |val| ConceptName.find_by_name(val).concept_id
    }
    @concepts_coded = "'" + @concepts.join("','") + "'"

    Relationship.find_by_sql("SELECT r.person_b FROM relationship r JOIN obs o ON o.person_id = r.person_b
				WHERE r.voided = 0 AND r.relationship = (SELECT relationship_type_id FROM relationship_type WHERE a_is_to_b = 'Mother' AND b_is_to_a = 'Child')
				AND DATE_FORMAT((SELECT birthdate FROM person WHERE person_id = r.person_b), '%Y-%m-%d') <= '#{enddate}' 
				AND DATE_FORMAT((SELECT birthdate FROM person WHERE person_id = r.person_b), '%Y-%m-%d') >= '#{startdate}' 
				AND o.concept_id IN (#{@concepts_coded})
				AND o.voided = 0
				AND o.value_coded = (SELECT concept_id FROM concept_name WHERE name = '#{field}' LIMIT 1)").each do |data| 

      weight = Observation.find(:last,
        :conditions => ["person_id = ? AND concept_id = ?",
          data.person_b, ConceptName.find_by_name("BIRTH WEIGHT").concept_id]).answer_string.to_i  rescue nil

      babies << data.person_b if weight.blank?
    end

    babies.delete_if{|baby| baby.blank?}
    render :text => babies.uniq.to_json
  end

  def missingweights_neonatal(startdate = Time.now, enddate = Time.now)
    babies = []

    @values = ['Neonatal death'].collect{
      |val| ConceptName.find_by_name(val).concept_id
    }
    @values_coded = "'" + @values.join("','") + "'"

    @concepts = ['BABY OUTCOME'].collect{
      |val| ConceptName.find_by_name(val).concept_id
    }

    @concepts_coded = "'" + @concepts.join("','") + "'"

    Relationship.find_by_sql("SELECT r.person_b FROM relationship r JOIN obs o ON o.person_id = r.person_b
				WHERE r.voided = 0 AND r.relationship = (SELECT relationship_type_id FROM relationship_type WHERE a_is_to_b = 'Mother' AND b_is_to_a = 'Child')
				AND DATE_FORMAT((SELECT birthdate FROM person WHERE person_id = r.person_b), '%Y-%m-%d') <= '#{enddate}'
				AND DATE_FORMAT((SELECT birthdate FROM person WHERE person_id = r.person_b), '%Y-%m-%d') >= '#{startdate}'
				AND o.concept_id IN (#{@concepts_coded})
				AND o.voided = 0
				AND (o.value_coded IN (#{@values_coded}) OR o.value_text IN ('Dead'))").each do |data|


      weight = Observation.find(:last,
        :conditions => ["person_id = ? AND concept_id = ?",
          data.person_b, ConceptName.find_by_name("BIRTH WEIGHT").concept_id]).answer_string.to_i  rescue nil

      babies << data.person_b if weight.blank?
    end

    babies.delete_if{|baby|
      baby.blank? or (Observation.find(:last, :conditions => ["person_id = ? AND concept_id = ?",
            baby, ConceptName.find_by_name("BABY OUTCOME").concept_id]).answer_string.blank? rescue false)
    }

    babies
  end
   
  def missingweights_predischarge(startdate = Time.now, enddate = Time.now)
    babies = []

    @values = ['Dead'].collect{
      |val| ConceptName.find_by_name(val).concept_id
    }
    @values_coded = "'" + @values.join("','") + "'"

    @concepts = ['STATUS OF BABY'].collect{
      |val| ConceptName.find_by_name(val).concept_id
    }
    @concepts_coded = "'" + @concepts.join("','") + "'"

    Relationship.find_by_sql("SELECT r.person_b FROM relationship r JOIN obs o ON o.person_id = r.person_b
				WHERE r.voided = 0 AND r.relationship = (SELECT relationship_type_id FROM relationship_type WHERE a_is_to_b = 'Mother' AND b_is_to_a = 'Child')
				AND DATE_FORMAT((SELECT birthdate FROM person WHERE person_id = r.person_b), '%Y-%m-%d') <= '#{enddate}' 
				AND DATE_FORMAT((SELECT birthdate FROM person WHERE person_id = r.person_b), '%Y-%m-%d') >= '#{startdate}' 
				AND o.concept_id IN (#{@concepts_coded})
				AND o.voided = 0
				AND (o.value_coded IN (#{@values_coded}) OR o.value_text IN ('Dead'))").each do |data|

      weight = Observation.find(:last,
        :conditions => ["person_id = ? AND concept_id = ?",
          data.person_b, ConceptName.find_by_name("BIRTH WEIGHT").concept_id]).answer_string.to_i  rescue nil

      babies << data.person_b if weight.blank?
    end
				
    babies.delete_if{|baby|
      baby.blank? or (Observation.find(:last, :conditions => ["person_id = ? AND concept_id = ?",
            baby, ConceptName.find_by_name("STATUS OF BABY").concept_id]).answer_string.blank? rescue false)
    }
    neo = missingweights_neonatal(startdate, enddate) rescue []
    babies = babies.concat(neo)
    render :text => babies.uniq.to_json
  end

  def missingweights_aliveatdischarge(startdate = Time.now, enddate = Time.now)
    babies = []
			
    Relationship.find_by_sql("SELECT r.person_b FROM relationship r JOIN obs o ON o.person_id = r.person_b
				WHERE r.voided = 0 AND r.relationship = (SELECT relationship_type_id FROM relationship_type WHERE a_is_to_b = 'Mother' AND b_is_to_a = 'Child')
				AND DATE_FORMAT((SELECT birthdate FROM person WHERE person_id = r.person_b), '%Y-%m-%d') <= '#{enddate}' 
				AND DATE_FORMAT((SELECT birthdate FROM person WHERE person_id = r.person_b), '%Y-%m-%d') >= '#{startdate}' 
				AND o.concept_id = (SELECT concept_id FROM concept_name WHERE name = 'STATUS OF BABY')
				AND o.voided = 0
				AND o.value_coded = (SELECT concept_id FROM concept_name WHERE name = 'Alive' LIMIT 1)").each do |data| 

      weight = Observation.find(:last,
        :conditions => ["person_id = ? AND concept_id = ?",
          data.person_b, ConceptName.find_by_name("BIRTH WEIGHT").concept_id]).answer_string.to_i  rescue nil

      babies << data.person_b if weight.blank?
    end

    babies.delete_if{|baby|
      baby.blank? or (Observation.find(:last, :conditions => ["person_id = ? AND concept_id = ?",
            baby, ConceptName.find_by_name("STATUS OF BABY").concept_id]).answer_string.blank? rescue false)
    }
    render :text => babies.uniq.to_json
  end

  def missingweights_missingoutcomes(startdate = Time.now, enddate = Time.now)
    babies = []

    @values = ['Neonatal death', 'Fresh still birth', 'Macerated still birth', 'Intrauterine death', 'Alive'].collect{
      |val| ConceptName.find_by_name(val).concept_id
    }
    @values_coded = "'" + @values.join("','") + "'"

    @concepts = ['BABY OUTCOME'].collect{
      |val| ConceptName.find_by_name(val).concept_id
    }
    @concepts_coded = "'" + @concepts.join("','") + "'"

    Relationship.find_by_sql("SELECT r.person_b FROM relationship r JOIN obs o ON o.person_id = r.person_b
				WHERE r.voided = 0 AND r.relationship = (SELECT relationship_type_id FROM relationship_type WHERE a_is_to_b = 'Mother' AND b_is_to_a = 'Child')
				AND DATE_FORMAT((SELECT birthdate FROM person WHERE person_id = r.person_b), '%Y-%m-%d') <= '#{enddate}' 
				AND DATE_FORMAT((SELECT birthdate FROM person WHERE person_id = r.person_b), '%Y-%m-%d') >= '#{startdate}' 
				AND o.concept_id IN (#{@concepts_coded})
				AND o.voided = 0
				AND (o.value_coded NOT IN (#{@values_coded})  								
								OR (SELECT COUNT(*) FROM obs WHERE person_id = r.person_b AND concept_id = (SELECT concept_id FROM concept_name WHERE name = 'BABY OUTCOME')) = 0
	)").each do |data| 

      weight = Observation.find(:last,
        :conditions => ["person_id = ? AND concept_id = ?",
          data.person_b, ConceptName.find_by_name("BIRTH WEIGHT").concept_id]).answer_string.to_i  rescue nil

      babies << data.person_b if weight.blank?
    end

    babies.delete_if{|baby|
      baby.blank? or (Observation.find(:last, :conditions => ["person_id = ? AND concept_id = ?",
            baby, ConceptName.find_by_name("STATUS OF BABY").concept_id]).answer_string.blank? rescue false)
    }
    render :text => babies.uniq.to_json
  end


  def missingweights_alive_predischarge(startdate = Time.now, enddate = Time.now)
    babies = []
    Relationship.find_by_sql("SELECT r.person_b FROM relationship r JOIN obs o ON o.person_id = r.person_b
				WHERE r.voided = 0 AND r.relationship = (SELECT relationship_type_id FROM relationship_type WHERE a_is_to_b = 'Mother' AND b_is_to_a = 'Child')
				AND DATE_FORMAT((SELECT birthdate FROM person WHERE person_id = r.person_b), '%Y-%m-%d') <= '#{enddate}'
				AND DATE_FORMAT((SELECT birthdate FROM person WHERE person_id = r.person_b), '%Y-%m-%d') >= '#{startdate}'
				AND o.concept_id = (SELECT concept_id FROM concept_name WHERE name = 'BABY OUTCOME')
				AND o.voided = 0
        AND (SELECT COUNT(*) FROM obs WHERE person_id = r.person_b AND voided = 0
            AND concept_id = (SELECT concept_id FROM concept_name WHERE name = 'STATUS OF BABY' LIMIT 1)) = 0
				AND o.value_coded IN (SELECT concept_id FROM concept_name WHERE name = 'Alive')").each do |data|

      weight = Observation.find(:last,
        :conditions => ["person_id = ? AND concept_id = ?",
          data.person_b, ConceptName.find_by_name("BIRTH WEIGHT").concept_id]).answer_string.to_i  rescue nil
      babies << data.person_b if weight.blank?
    end
    
    babies.delete_if{|baby| baby.blank? }
    babies
	end
  
  def missingweights_total(startdate = Time.now, enddate = Time.now)
    babies = []

    @values = ['Neonatal death', 'Fresh still birth', 'Macerated still birth', 'Intrauterine death', 'Alive'].collect{
      |val| ConceptName.find_by_name(val).concept_id
    }
    @values_coded = "'" + @values.join("','") + "'"

    @concepts = ['BABY OUTCOME', 'STATUS OF BABY'].collect{
      |val| ConceptName.find_by_name(val).concept_id
    }
    @concepts_coded = "'" + @concepts.join("','") + "'"

    Relationship.find_by_sql("SELECT r.person_b FROM relationship r JOIN obs o ON o.person_id = r.person_b
				WHERE r.voided = 0 AND r.relationship = (SELECT relationship_type_id FROM relationship_type WHERE a_is_to_b = 'Mother' AND b_is_to_a = 'Child')
				AND DATE_FORMAT((SELECT birthdate FROM person WHERE person_id = r.person_b), '%Y-%m-%d') <= '#{enddate}' 
				AND DATE_FORMAT((SELECT birthdate FROM person WHERE person_id = r.person_b), '%Y-%m-%d') >= '#{startdate}'
				AND o.voided = 0 
				AND o.concept_id IN (#{@concepts_coded})").each do |data| 

      weight = Observation.find(:last,
        :conditions => ["person_id = ? AND concept_id = ?",
          data.person_b, ConceptName.find_by_name("BIRTH WEIGHT").concept_id]).answer_string.to_i  rescue nil

      babies << data.person_b if weight.blank?
    end

    alive_without_discharge = missingweights_alive_predischarge(startdate, enddate)
    babies  = babies - alive_without_discharge
    babies.delete_if{|baby|
      baby.blank? or (Observation.find(:last, :conditions => ["person_id = ? AND concept_id = ?",
            baby, ConceptName.find_by_name("STATUS OF BABY").concept_id]).answer_string.blank? rescue false)
    }
    render :text => babies.uniq.to_json
  end
	
  def total(startdate = Time.now, enddate = Time.now, field = 'blank')
    babies = []

    @concepts = ['BABY OUTCOME', 'STATUS OF BABY'].collect{
      |val| ConceptName.find_by_name(val).concept_id
    }
    @concepts_coded = "'" + @concepts.join("','") + "'"

    Relationship.find_by_sql("SELECT r.person_b FROM relationship r JOIN obs o ON o.person_id = r.person_b
				WHERE r.voided = 0 AND r.relationship = (SELECT relationship_type_id FROM relationship_type WHERE a_is_to_b = 'Mother' AND b_is_to_a = 'Child')
				AND DATE_FORMAT((SELECT birthdate FROM person WHERE person_id = r.person_b), '%Y-%m-%d') <= '#{enddate}' 
				AND DATE_FORMAT((SELECT birthdate FROM person WHERE person_id = r.person_b), '%Y-%m-%d') >= '#{startdate}' 
				AND o.voided = 0
				AND o.concept_id IN (#{@concepts_coded})
				AND o.value_coded = (SELECT concept_id FROM concept_name WHERE name = '#{field}' LIMIT 1)").each do |data| 

      babies << data.person_b
    end

    babies.delete_if{|baby| baby.blank?}
    render :text => babies.uniq.to_json
  end

  def total_neonatal(startdate = Time.now, enddate = Time.now)
    babies = []

    @values = ['Neonatal death'].collect{
      |val| ConceptName.find_by_name(val).concept_id
    }
    @values_coded = "'" + @values.join("','") + "'"

    @concepts = ['BABY OUTCOME'].collect{
      |val| ConceptName.find_by_name(val).concept_id
    }

    @concepts_coded = "'" + @concepts.join("','") + "'"

    Relationship.find_by_sql("SELECT r.person_b FROM relationship r JOIN obs o ON o.person_id = r.person_b
				WHERE r.voided = 0 AND r.relationship = (SELECT relationship_type_id FROM relationship_type WHERE a_is_to_b = 'Mother' AND b_is_to_a = 'Child')
				AND DATE_FORMAT((SELECT birthdate FROM person WHERE person_id = r.person_b), '%Y-%m-%d') <= '#{enddate}'
				AND DATE_FORMAT((SELECT birthdate FROM person WHERE person_id = r.person_b), '%Y-%m-%d') >= '#{startdate}'
				AND o.concept_id IN (#{@concepts_coded})
				AND o.voided = 0
				AND (o.value_coded IN (#{@values_coded}) OR o.value_text IN ('Dead'))").each do |data|


      weight = Observation.find(:last,
        :conditions => ["person_id = ? AND concept_id = ?",
          data.person_b, ConceptName.find_by_name("BIRTH WEIGHT").concept_id]).answer_string.to_i  rescue nil

      babies << data.person_b
    end

    babies.delete_if{|baby|
      baby.blank? or (Observation.find(:last, :conditions => ["person_id = ? AND concept_id = ?",
            baby, ConceptName.find_by_name("BABY OUTCOME").concept_id]).answer_string.blank? rescue false)
    }

    babies
  end

  def total_predischarge(startdate = Time.now, enddate = Time.now)
    babies = []

    @values = ['Dead'].collect{
      |val| ConceptName.find_by_name(val).concept_id
    }
    @values_coded = "'" + @values.join("','") + "'"

    @concepts = ['STATUS OF BABY'].collect{
      |val| ConceptName.find_by_name(val).concept_id
    }
    @concepts_coded = "'" + @concepts.join("','") + "'"

    Relationship.find_by_sql("SELECT r.person_b FROM relationship r JOIN obs o ON o.person_id = r.person_b
				WHERE r.voided = 0 AND r.relationship = (SELECT relationship_type_id FROM relationship_type WHERE a_is_to_b = 'Mother' AND b_is_to_a = 'Child')
				AND DATE_FORMAT((SELECT birthdate FROM person WHERE person_id = r.person_b), '%Y-%m-%d') <= '#{enddate}' 
				AND DATE_FORMAT((SELECT birthdate FROM person WHERE person_id = r.person_b), '%Y-%m-%d') >= '#{startdate}' 
				AND o.concept_id IN (#{@concepts_coded})
				AND o.voided = 0
				AND (o.value_coded IN (#{@values_coded}) OR o.value_text IN ('Dead'))").each do |data|


      babies << data.person_b
    end
				
    babies.delete_if{|baby|
      baby.blank? or (Observation.find(:last, :conditions => ["person_id = ? AND concept_id = ?",
            baby, ConceptName.find_by_name("STATUS OF BABY").concept_id]).answer_string.blank? rescue false)
    }
    neo = total_neonatal(startdate, enddate) rescue []
    babies = babies.concat(neo)
    render :text => babies.uniq.to_json
  end

  def total_aliveatdischarge(startdate = Time.now, enddate = Time.now)
    babies = []
			
    Relationship.find_by_sql("SELECT r.person_b FROM relationship r JOIN obs o ON o.person_id = r.person_b
				WHERE r.voided = 0 AND r.relationship = (SELECT relationship_type_id FROM relationship_type WHERE a_is_to_b = 'Mother' AND b_is_to_a = 'Child')
				AND DATE_FORMAT((SELECT birthdate FROM person WHERE person_id = r.person_b), '%Y-%m-%d') <= '#{enddate}' 
				AND DATE_FORMAT((SELECT birthdate FROM person WHERE person_id = r.person_b), '%Y-%m-%d') >= '#{startdate}' 
				AND o.concept_id = (SELECT concept_id FROM concept_name WHERE name = 'STATUS OF BABY')
				AND o.voided = 0
				AND o.value_coded = (SELECT concept_id FROM concept_name WHERE name = 'Alive' LIMIT 1)").each do |data| 
      babies << data.person_b
    end

    babies.delete_if{|baby|
      baby.blank? or (Observation.find(:last, :conditions => ["person_id = ? AND concept_id = ?",
            baby, ConceptName.find_by_name("STATUS OF BABY").concept_id]).answer_string.blank? rescue false)
    }
    render :text => babies.uniq.to_json
  end

  def total_missingoutcomes(startdate = Time.now, enddate = Time.now)
    babies = []

    @values = ['Neonatal death', 'Fresh still birth', 'Macerated still birth', 'Intrauterine death', 'Alive'].collect{
      |val| ConceptName.find_by_name(val).concept_id
    }
    @values_coded = "'" + @values.join("','") + "'"

    @concepts = ['BABY OUTCOME'].collect{
      |val| ConceptName.find_by_name(val).concept_id
    }
    @concepts_coded = "'" + @concepts.join("','") + "'"

    Relationship.find_by_sql("SELECT r.person_b FROM relationship r JOIN obs o ON o.person_id = r.person_b
				WHERE r.voided = 0 AND r.relationship = (SELECT relationship_type_id FROM relationship_type WHERE a_is_to_b = 'Mother' AND b_is_to_a = 'Child')
				AND DATE_FORMAT((SELECT birthdate FROM person WHERE person_id = r.person_b), '%Y-%m-%d') <= '#{enddate}' 
				AND DATE_FORMAT((SELECT birthdate FROM person WHERE person_id = r.person_b), '%Y-%m-%d') >= '#{startdate}' 
				AND o.concept_id IN (#{@concepts_coded})
				AND o.voided = 0
				AND (o.value_coded NOT IN (#{@values_coded})  
								OR (SELECT COUNT(*) FROM obs WHERE person_id = r.person_b AND concept_id = (SELECT concept_id FROM concept_name WHERE name = 'BABY OUTCOME')) = 0
	)").each do |data| 

      babies << data.person_b
 					
    end

    babies.delete_if{|baby|
      baby.blank?
    }
    render :text => babies.uniq.to_json
  end

  def total_alive_predischarge(startdate = Time.now, enddate = Time.now)
    babies = []
    Relationship.find_by_sql("SELECT r.person_b FROM relationship r JOIN obs o ON o.person_id = r.person_b
				WHERE r.voided = 0 AND r.relationship = (SELECT relationship_type_id FROM relationship_type WHERE a_is_to_b = 'Mother' AND b_is_to_a = 'Child')
				AND DATE_FORMAT((SELECT birthdate FROM person WHERE person_id = r.person_b), '%Y-%m-%d') <= '#{enddate}'
				AND DATE_FORMAT((SELECT birthdate FROM person WHERE person_id = r.person_b), '%Y-%m-%d') >= '#{startdate}'
				AND o.concept_id = (SELECT concept_id FROM concept_name WHERE name = 'BABY OUTCOME')
				AND o.voided = 0
        AND (SELECT COUNT(*) FROM obs WHERE person_id = r.person_b AND voided = 0
            AND concept_id = (SELECT concept_id FROM concept_name WHERE name = 'STATUS OF BABY' LIMIT 1)) = 0
				AND o.value_coded IN (SELECT concept_id FROM concept_name WHERE name = 'Alive')").each do |data|

      babies << data.person_b
    end

    babies.delete_if{|baby| baby.blank? }
    babies
	end
 
  def total_total(startdate = Time.now, enddate = Time.now)
    babies = []

    @values = ['Neonatal death', 'Fresh still birth', 'Macerated still birth', 'Intrauterine death', 'Alive'].collect{
      |val| ConceptName.find_by_name(val).concept_id
    }
    @values_coded = "'" + @values.join("','") + "'"

    @concepts = ['BABY OUTCOME', 'STATUS OF BABY'].collect{
      |val| ConceptName.find_by_name(val).concept_id
    }
    @concepts_coded = "'" + @concepts.join("','") + "'"

    Relationship.find_by_sql("SELECT r.person_b FROM relationship r
			  JOIN obs o ON o.person_id = r.person_b 
				WHERE r.voided = 0 AND r.relationship = (SELECT relationship_type_id FROM relationship_type WHERE a_is_to_b = 'Mother' AND b_is_to_a = 'Child')
				AND DATE_FORMAT((SELECT birthdate FROM person WHERE person_id = r.person_b), '%Y-%m-%d') <= '#{enddate}' 
				AND DATE_FORMAT((SELECT birthdate FROM person WHERE person_id = r.person_b), '%Y-%m-%d') >= '#{startdate}' 
				AND o.voided = 0
				AND o.concept_id IN (#{@concepts_coded})").each do |data| 

      babies << data.person_b
    end

    alive_without_discharge = total_alive_predischarge(startdate, enddate)
    babies = babies - alive_without_discharge

    babies.delete_if{|baby|
      baby.blank?
    }

    render :text => babies.uniq.to_json
  end

  def birth_cohort
    
    @system_upgrade_date = Relationship.find(:first, :order => ["date_created ASC"], :conditions => ["relationship = ?",
        RelationshipType.find_by_a_is_to_b_and_b_is_to_a("Mother", "Child")]).date_created.to_date rescue "2013-04-20"

    params[:start_date] = @system_upgrade_date.blank?? params[:start_date] : (@system_upgrade_date > params[:start_date].to_date ? @system_upgrade_date : params[:start_date])
    
    @total_admissions = Patient.total_admissions(params[:start_date], params[:end_date]) rescue []
   
    @ctotal_admissions = Patient.total_admissions(@system_upgrade_date, params[:end_date]) rescue []

    @total_mothers = Patient.total_mothers_in_range(params[:start_date], params[:end_date],  @total_admissions) rescue []

    @maternal_outcomes = {}
    @maternal_outcomes["DEAD"] = Patient.deaths(@total_admissions, params[:start_date], params[:end_date])
    @maternal_outcomes["ALIVE"] = @total_admissions - @maternal_outcomes["DEAD"]

    @cmaternal_outcomes = {}
    @cmaternal_outcomes["DEAD"] = Patient.deaths(@total_admissions, @system_upgrade_date, params[:end_date])
    @cmaternal_outcomes["ALIVE"] = @ctotal_admissions - @cmaternal_outcomes["DEAD"]

    
    @total_delivery_counts = Relationship.twins_pull(@total_admissions, params[:start_date], params[:end_date])
    @ctotal_delivery_counts = Relationship.twins_pull(@ctotal_admissions, @system_upgrade_date, params[:end_date])

    @twins = {}
    @twins["1"] = @total_delivery_counts.collect{|mother| mother.patient_id if mother.counter.to_i == 1}.compact.uniq
    @twins["2"] = @total_delivery_counts.collect{|mother| mother.patient_id if mother.counter.to_i == 2}.compact.uniq
    @twins["3"] = @total_delivery_counts.collect{|mother| mother.patient_id if mother.counter.to_i == 3}.compact.uniq
    @twins["4"] = @total_delivery_counts.collect{|mother| mother.patient_id if mother.counter.to_i == 4}.compact.uniq
    @twins[">4"] =  @total_delivery_counts.collect{|mother| mother.patient_id if mother.counter.to_i > 4}.compact.uniq

    @ctwins = {}
    @ctwins["1"] = @ctotal_delivery_counts.collect{|mother| mother.patient_id if mother.counter.to_i == 1}.compact.uniq
    @ctwins["2"] = @ctotal_delivery_counts.collect{|mother| mother.patient_id if mother.counter.to_i == 2}.compact.uniq
    @ctwins["3"] = @ctotal_delivery_counts.collect{|mother| mother.patient_id if mother.counter.to_i == 3}.compact.uniq
    @ctwins["4"] = @ctotal_delivery_counts.collect{|mother| mother.patient_id if mother.counter.to_i == 4}.compact.uniq
    @ctwins[">4"] = @ctotal_delivery_counts.collect{|mother| mother.patient_id if mother.counter.to_i > 4}.compact.uniq

    
    @ctotal_mothers = Patient.total_mothers_in_range(@system_upgrade_date, params[:end_date],  @ctotal_admissions) rescue []

    @total_babies = Relationship.total_babies_in_range(params[:start_date], params[:end_date]) rescue []
    
    @ctotal_babies = Relationship.total_babies_in_range(@system_upgrade_date, params[:end_date]) rescue []
    
    @total_babies_born = @total_babies.collect{|baby| baby.person_id rescue nil}.compact rescue []
    @ctotal_babies_born = @ctotal_babies.collect{|baby| baby.person_id rescue nil}.compact rescue []
  
    @delivery_weeks = {}
    @delivery_weeks["PRE_TERM"] = @total_mothers.collect{|mother| mother.patient_id if ((mother.weeks.present? && mother.weeks.to_i < 34 && mother.weeks.to_i > 1)rescue false)}.compact.uniq
    @delivery_weeks["NEAR_TERM"] = @total_mothers.collect{|mother| mother.patient_id if ((mother.weeks.present? && mother.weeks.to_i >= 34 && mother.weeks.to_i <= 37)rescue false)}.compact.uniq
    @delivery_weeks["POST_TERM"] = @total_mothers.collect{|mother| mother.patient_id if ((mother.weeks.present? && mother.weeks.to_i > 42)rescue false)}.compact.uniq
    @delivery_weeks["FULL_TERM"] = @total_mothers.collect{|mother| mother.patient_id if ((mother.weeks.present? && mother.weeks.to_i >= 38 && mother.weeks.to_i <= 42)rescue false)}.compact.uniq
    @delivery_weeks["UNKNOWN"] = @total_mothers.collect{|mother| mother.patient_id if mother.weeks.blank? || mother.weeks.to_i <= 1}.compact.uniq

    @cdelivery_weeks = {}
    @cdelivery_weeks["PRE_TERM"] = @ctotal_mothers.collect{|mother| mother.patient_id if ((mother.weeks.present? && mother.weeks.to_i < 34)rescue false)}.compact.uniq
    @cdelivery_weeks["NEAR_TERM"] = @ctotal_mothers.collect{|mother| mother.patient_id if ((mother.weeks.present? && mother.weeks.to_i >= 34 && mother.weeks.to_i <= 37)rescue false)}.compact.uniq
    @cdelivery_weeks["POST_TERM"] = @ctotal_mothers.collect{|mother| mother.patient_id if ((mother.weeks.present? && mother.weeks.to_i > 42)rescue false)}.compact.uniq
    @cdelivery_weeks["FULL_TERM"] = @ctotal_mothers.collect{|mother| mother.patient_id if ((mother.weeks.present? && mother.weeks.to_i >= 38 && mother.weeks.to_i <= 42)rescue false)}.compact.uniq
    @cdelivery_weeks["UNKNOWN"] = @ctotal_mothers.collect{|mother| mother.patient_id if mother.weeks.blank?}.compact.uniq


    @birth_report_status = {}
    @birth_report_status["SENT"] = @total_babies.collect{|baby| baby.person_id if ((baby.br_status.present? && baby.br_status.match(/SENT/i))rescue false)}.compact.uniq
    @birth_report_status["PENDING"] = @total_babies.collect{|baby| baby.person_id if ((baby.br_status.present? && baby.br_status.match(/PENDING/i))rescue false)}.compact.uniq
    @birth_report_status["UNATTEMPTED"] = @total_babies.collect{|baby| baby.person_id if ((baby.br_status.present? && baby.br_status.match(/UNATTEMPTED/i))rescue false)}.compact.uniq
    @birth_report_status["UNKNOWN"] = @total_babies.collect{|baby| baby.person_id if ((baby.br_status.present? && baby.br_status.match(/UNKNOWN/i))rescue false)}.compact.uniq

    @cbirth_report_status = {}
    @cbirth_report_status["SENT"] = @ctotal_babies.collect{|baby| baby.person_id if ((baby.br_status.present? && baby.br_status.match(/SENT/i))rescue false)}.compact.uniq
    @cbirth_report_status["PENDING"] = @ctotal_babies.collect{|baby| baby.person_id if ((baby.br_status.present? && baby.br_status.match(/PENDING/i))rescue false)}.compact.uniq
    @cbirth_report_status["UNATTEMPTED"] = @ctotal_babies.collect{|baby| baby.person_id if ((baby.br_status.present? && baby.br_status.match(/UNATTEMPTED/i))rescue false)}.compact.uniq
    @cbirth_report_status["UNKNOWN"] = @ctotal_babies.collect{|baby| baby.person_id if ((baby.br_status.present? && baby.br_status.match(/UNKNOWN/i))rescue false)}.compact.uniq

    @gender = {}
    @gender["MALES"] = @total_babies.collect{|baby| baby.person_id if !baby.gender.match(/F/i)}.compact.uniq
    @gender["FEMALES"] = @total_babies.collect{|baby| baby.person_id if baby.gender.match(/F/i)}.compact.uniq
    @cgender = {}
    @cgender["MALES"] = @ctotal_babies.collect{|baby| baby.person_id if !baby.gender.match(/F/i)}.compact.uniq
    @cgender["FEMALES"] = @ctotal_babies.collect{|baby| baby.person_id if baby.gender.match(/F/i)}.compact.uniq

    @apgar1 = {}
    @apgar2 = {}
    @capgar1 = {}
    @capgar2 = {}
    
    @apgar1["FE_LOW"] = @total_babies.collect{|baby| baby.person_id if baby.apgar.present? && baby.apgar.to_i <= 3 && baby.gender.match(/F/i)}.compact.uniq
    @apgar1["FE_FAIRLY_LOW"] = @total_babies.collect{|baby| baby.person_id if baby.apgar.present? && baby.apgar.to_i > 3 && baby.apgar.to_i < 7 && baby.gender.match(/F/i)}.compact.uniq
    @apgar1["FE_NORMAL"] = @total_babies.collect{|baby| baby.person_id if baby.apgar.present? && baby.apgar.to_i >= 7 && baby.gender.match(/F/i)}.compact.uniq
    @apgar1["FE_UNKNOWN"] = (@gender["FEMALES"] - (@apgar1["FE_LOW"] + @apgar1["FE_FAIRLY_LOW"] + @apgar1["FE_NORMAL"] ))

    @apgar2["FE_LOW"] = @total_babies.collect{|baby| baby.person_id if  baby.apgar2.present? && baby.apgar2.to_i <= 3 && baby.gender.match(/F/i)}.compact.uniq
    @apgar2["FE_FAIRLY_LOW"] = @total_babies.collect{|baby| baby.person_id if baby.apgar2.present? && baby.apgar2.to_i > 3 && baby.apgar2.to_i < 7 && baby.gender.match(/F/i)}.compact.uniq
    @apgar2["FE_NORMAL"] = @total_babies.collect{|baby| baby.person_id if baby.apgar2.present? && baby.apgar2.to_i >= 7 && baby.gender.match(/F/i)}.compact.uniq
    @apgar2["FE_UNKNOWN"] = (@gender["FEMALES"] - (@apgar2["FE_NORMAL"] + @apgar2["FE_FAIRLY_LOW"] + @apgar2["FE_LOW"]))

    @apgar1["MALE_LOW"] = @total_babies.collect{|baby| baby.person_id if baby.apgar.present? && baby.apgar.to_i <= 3 && !baby.gender.match(/F/i)}.compact.uniq
    @apgar1["MALE_FAIRLY_LOW"] = @total_babies.collect{|baby| baby.person_id if  baby.apgar.present? && baby.apgar.to_i > 3 && baby.apgar.to_i < 7 && !baby.gender.match(/F/i)}.compact.uniq
    @apgar1["MALE_NORMAL"] = @total_babies.collect{|baby| baby.person_id if  baby.apgar.present? && baby.apgar.to_i >= 7 && !baby.gender.match(/F/i)}.compact.uniq
    @apgar1["MALE_UNKNOWN"] = (@gender["MALES"] - (@apgar1["MALE_NORMAL"] + @apgar1["MALE_FAIRLY_LOW"] + @apgar1["MALE_LOW"]))

    @apgar2["MALE_LOW"] = @total_babies.collect{|baby| baby.person_id if baby.apgar2.present? && baby.apgar2.to_i <= 3 && !baby.gender.match(/F/i)}.compact.uniq
    @apgar2["MALE_FAIRLY_LOW"] = @total_babies.collect{|baby| baby.person_id if baby.apgar2.present? && baby.apgar2.to_i > 3 && baby.apgar2.to_i < 7 && !baby.gender.match(/F/i)}.compact.uniq
    @apgar2["MALE_NORMAL"] = @total_babies.collect{|baby| baby.person_id if baby.apgar2.present? && baby.apgar2.to_i >= 7 && !baby.gender.match(/F/i)}.compact.uniq
    @apgar2["MALE_UNKNOWN"] = (@gender["MALES"]  - (@apgar2["MALE_LOW"] + @apgar2["MALE_FAIRLY_LOW"] + @apgar2["MALE_NORMAL"]))

    # for cumulative totals
    @capgar1["FE_LOW"] = @ctotal_babies.collect{|baby| baby.person_id if baby.apgar.present? && baby.apgar.to_i <= 3 && baby.gender.match(/F/i)}.compact.uniq
    @capgar1["FE_FAIRLY_LOW"] = @ctotal_babies.collect{|baby| baby.person_id if baby.apgar.present? && baby.apgar.to_i > 3 && baby.apgar.to_i < 7 && baby.gender.match(/F/i)}.compact.uniq
    @capgar1["FE_NORMAL"] = @ctotal_babies.collect{|baby| baby.person_id if baby.apgar.present? && baby.apgar.to_i >= 7 && baby.gender.match(/F/i)}.compact.uniq
    @capgar1["FE_UNKNOWN"] = (@cgender["FEMALES"] - (@capgar1["FE_LOW"] + @capgar1["FE_FAIRLY_LOW"] + @capgar1["FE_NORMAL"] ))

    @capgar2["FE_LOW"] = @ctotal_babies.collect{|baby| baby.person_id if  baby.apgar2.present? && baby.apgar2.to_i <= 3 && baby.gender.match(/F/i)}.compact.uniq
    @capgar2["FE_FAIRLY_LOW"] = @ctotal_babies.collect{|baby| baby.person_id if baby.apgar2.present? && baby.apgar2.to_i > 3 && baby.apgar2.to_i < 7 && baby.gender.match(/F/i)}.compact.uniq
    @capgar2["FE_NORMAL"] = @ctotal_babies.collect{|baby| baby.person_id if baby.apgar2.present? && baby.apgar2.to_i >= 7 && baby.gender.match(/F/i)}.compact.uniq
    @capgar2["FE_UNKNOWN"] = (@cgender["FEMALES"] - (@capgar2["FE_NORMAL"] + @capgar2["FE_FAIRLY_LOW"] + @capgar2["FE_LOW"]))

    @capgar1["MALE_LOW"] = @ctotal_babies.collect{|baby| baby.person_id if baby.apgar.present? && baby.apgar.to_i <= 3 && !baby.gender.match(/F/i)}.compact.uniq
    @capgar1["MALE_FAIRLY_LOW"] = @ctotal_babies.collect{|baby| baby.person_id if  baby.apgar.present? && baby.apgar.to_i > 3 && baby.apgar.to_i < 7 && !baby.gender.match(/F/i)}.compact.uniq
    @capgar1["MALE_NORMAL"] = @ctotal_babies.collect{|baby| baby.person_id if  baby.apgar.present? && baby.apgar.to_i >= 7 && !baby.gender.match(/F/i)}.compact.uniq
    @capgar1["MALE_UNKNOWN"] = (@cgender["MALES"] - (@capgar1["MALE_NORMAL"] + @capgar1["MALE_FAIRLY_LOW"] + @capgar1["MALE_LOW"]))

    @capgar2["MALE_LOW"] = @ctotal_babies.collect{|baby| baby.person_id if baby.apgar2.present? && baby.apgar2.to_i <= 3 && !baby.gender.match(/F/i)}.compact.uniq
    @capgar2["MALE_FAIRLY_LOW"] = @ctotal_babies.collect{|baby| baby.person_id if baby.apgar2.present? && baby.apgar2.to_i > 3 && baby.apgar2.to_i < 7 && !baby.gender.match(/F/i)}.compact.uniq
    @capgar2["MALE_NORMAL"] = @ctotal_babies.collect{|baby| baby.person_id if baby.apgar2.present? && baby.apgar2.to_i >= 7 && !baby.gender.match(/F/i)}.compact.uniq
    @capgar2["MALE_UNKNOWN"] = (@cgender["MALES"]  - (@capgar2["MALE_LOW"] + @capgar2["MALE_FAIRLY_LOW"] + @capgar2["MALE_NORMAL"]))
    
    @delivery_mode = {}
    @delivery_mode["MALE_ALIVE"] = @total_babies.collect{|baby| baby.person_id if baby.delivery_outcome.match(/Alive/i) && !baby.gender.match(/F/i)}.compact.uniq
    @delivery_mode["MALE_NEO"] = @total_babies.collect{|baby| baby.person_id if baby.delivery_outcome.match(/Neonatal death/i) && !baby.gender.match(/F/i)}.compact.uniq
    @delivery_mode["MALE_FRESH"] = @total_babies.collect{|baby| baby.person_id if baby.delivery_outcome.match(/Fresh still birth/i) && !baby.gender.match(/F/i)}.compact.uniq
    @delivery_mode["MALE_MAC"] = @total_babies.collect{|baby| baby.person_id if baby.delivery_outcome.match(/Macerated still birth/i) && !baby.gender.match(/F/i)}.compact.uniq

    @delivery_mode["F_ALIVE"] = @total_babies.collect{|baby| baby.person_id if baby.delivery_outcome.match(/Alive/i) && baby.gender.match(/F/i)}.compact.uniq
    @delivery_mode["F_NEO"] = @total_babies.collect{|baby| baby.person_id if baby.delivery_outcome.match(/Neonatal death/i) && baby.gender.match(/F/i)}.compact.uniq
    @delivery_mode["F_FRESH"] = @total_babies.collect{|baby| baby.person_id if baby.delivery_outcome.match(/Fresh still birth/i) && baby.gender.match(/F/i)}.compact.uniq
    @delivery_mode["F_MAC"] = @total_babies.collect{|baby| baby.person_id if baby.delivery_outcome.match(/Macerated still birth/i) && baby.gender.match(/F/i)}.compact.uniq

    #cumulative delivery outcomes
    @cdelivery_mode = {}
    @cdelivery_mode["MALE_ALIVE"] = @ctotal_babies.collect{|baby| baby.person_id if baby.delivery_outcome.match(/Alive/i) && !baby.gender.match(/F/i)}.compact.uniq
    @cdelivery_mode["MALE_NEO"] = @ctotal_babies.collect{|baby| baby.person_id if baby.delivery_outcome.match(/Neonatal death/i) && !baby.gender.match(/F/i)}.compact.uniq
    @cdelivery_mode["MALE_FRESH"] = @ctotal_babies.collect{|baby| baby.person_id if baby.delivery_outcome.match(/Fresh still birth/i) && !baby.gender.match(/F/i)}.compact.uniq
    @cdelivery_mode["MALE_MAC"] = @ctotal_babies.collect{|baby| baby.person_id if baby.delivery_outcome.match(/Macerated still birth/i) && !baby.gender.match(/F/i)}.compact.uniq

    @cdelivery_mode["F_ALIVE"] = @ctotal_babies.collect{|baby| baby.person_id if baby.delivery_outcome.match(/Alive/i) && baby.gender.match(/F/i)}.compact.uniq
    @cdelivery_mode["F_NEO"] = @ctotal_babies.collect{|baby| baby.person_id if baby.delivery_outcome.match(/Neonatal death/i) && baby.gender.match(/F/i)}.compact.uniq
    @cdelivery_mode["F_FRESH"] = @ctotal_babies.collect{|baby| baby.person_id if baby.delivery_outcome.match(/Fresh still birth/i) && baby.gender.match(/F/i)}.compact.uniq
    @cdelivery_mode["F_MAC"] = @ctotal_babies.collect{|baby| baby.person_id if baby.delivery_outcome.match(/Macerated still birth/i) && baby.gender.match(/F/i)}.compact.uniq

    
    @discharge_outcome = {}
    @discharge_outcome["MALE_ALIVE"] = @total_babies.collect{|baby| baby.person_id if (baby.discharge_outcome.match(/Alive/i) rescue false) && !baby.gender.match(/F/i)}.compact.uniq
    @discharge_outcome["MALE_DEAD"] = @total_babies.collect{|baby| baby.person_id if (!baby.delivery_outcome.match(/Alive/i)) && !baby.gender.match(/F/i)}.compact.uniq
    @discharge_outcome["MALE_NOT_DISCHARGED"] = (@gender["MALES"] - (@discharge_outcome["MALE_ALIVE"] + @discharge_outcome["MALE_DEAD"])).uniq
    
    @discharge_outcome["F_ALIVE"] = @total_babies.collect{|baby| baby.person_id if (baby.discharge_outcome.match(/Alive/i) rescue false) && baby.gender.match(/F/i)}.compact.uniq
    @discharge_outcome["F_DEAD"] = @total_babies.collect{|baby| baby.person_id if (!baby.delivery_outcome.match(/Alive/i)) && baby.gender.match(/F/i)}.compact.uniq
    @discharge_outcome["F_NOT_DISCHARGED"] = (@gender["FEMALES"] - (@discharge_outcome["F_ALIVE"] + @discharge_outcome["F_DEAD"])).uniq

    #cumulative discharges
    @cdischarge_outcome = {}
    @cdischarge_outcome["MALE_ALIVE"] = @ctotal_babies.collect{|baby| baby.person_id if (baby.discharge_outcome.match(/Alive/i) rescue false) && !baby.gender.match(/F/i)}.compact.uniq
    @cdischarge_outcome["MALE_DEAD"] = @ctotal_babies.collect{|baby| baby.person_id if (!baby.delivery_outcome.match(/Alive/i)) && !baby.gender.match(/F/i)}.compact.uniq
    @cdischarge_outcome["MALE_NOT_DISCHARGED"] = (@cgender["MALES"] - (@cdischarge_outcome["MALE_ALIVE"] + @cdischarge_outcome["MALE_DEAD"])).uniq

    @cdischarge_outcome["F_ALIVE"] = @ctotal_babies.collect{|baby| baby.person_id if (baby.discharge_outcome.match(/Alive/i) rescue false) && baby.gender.match(/F/i)}.compact.uniq
    @cdischarge_outcome["F_DEAD"] = @ctotal_babies.collect{|baby| baby.person_id if (!baby.delivery_outcome.match(/Alive/i)) && baby.gender.match(/F/i)}.compact.uniq
    @cdischarge_outcome["F_NOT_DISCHARGED"] = (@cgender["FEMALES"] - (@cdischarge_outcome["F_ALIVE"] + @cdischarge_outcome["F_DEAD"])).uniq
    
    @weights = {}
    @weights["MALE_LOW"] = @total_babies.collect{|baby| baby.person_id if ((baby.birth_weight.to_i != 0 && baby.birth_weight.to_i < 2500) rescue false) && !baby.gender.match(/F/i)}.compact.uniq
    @weights["MALE_NORMAL"] = @total_babies.collect{|baby| baby.person_id if ((baby.birth_weight.to_i >= 2500 && baby.birth_weight.to_i <= 4500) rescue false) && !baby.gender.match(/F/i)}.compact.uniq
    @weights["MALE_HIGH"] = @total_babies.collect{|baby| baby.person_id if ((baby.birth_weight.to_i > 4500) rescue false) && !baby.gender.match(/F/i)}.compact.uniq
    @weights["MALE_UNKNOWN"] =  (@gender["MALES"] - (@weights["MALE_LOW"] + @weights["MALE_NORMAL"] + @weights["MALE_HIGH"])).uniq

    @weights["FE_LOW"] = @total_babies.collect{|baby| baby.person_id if ((baby.birth_weight.to_i != 0 && baby.birth_weight.to_i < 2500) rescue false) && baby.gender.match(/F/i)}.compact.uniq
    @weights["FE_NORMAL"] = @total_babies.collect{|baby| baby.person_id if ((baby.birth_weight.to_i >= 2500 && baby.birth_weight.to_i <= 4500) rescue false) && baby.gender.match(/F/i)}.compact.uniq
    @weights["FE_HIGH"] = @total_babies.collect{|baby| baby.person_id if ((baby.birth_weight.to_i > 4500) rescue false) && baby.gender.match(/F/i)}.compact.uniq
    @weights["FE_UNKNOWN"] = (@gender["FEMALES"] - (@weights["FE_LOW"] + @weights["FE_NORMAL"] + @weights["FE_HIGH"])).uniq

    #weight for cumulative outcomes
    @cweights = {}
    @cweights["MALE_LOW"] = @ctotal_babies.collect{|baby| baby.person_id if ((baby.birth_weight.to_i != 0 && baby.birth_weight.to_i < 2500) rescue false) && !baby.gender.match(/F/i)}.compact.uniq
    @cweights["MALE_NORMAL"] = @ctotal_babies.collect{|baby| baby.person_id if ((baby.birth_weight.to_i >= 2500 && baby.birth_weight.to_i <= 4500) rescue false) && !baby.gender.match(/F/i)}.compact.uniq
    @cweights["MALE_HIGH"] = @ctotal_babies.collect{|baby| baby.person_id if ((baby.birth_weight.to_i > 4500) rescue false) && !baby.gender.match(/F/i)}.compact.uniq
    @cweights["MALE_UNKNOWN"] =  (@cgender["MALES"] - (@cweights["MALE_LOW"] + @cweights["MALE_NORMAL"] + @cweights["MALE_HIGH"])).uniq

    @cweights["FE_LOW"] = @ctotal_babies.collect{|baby| baby.person_id if ((baby.birth_weight.to_i != 0 && baby.birth_weight.to_i < 2500) rescue false) && baby.gender.match(/F/i)}.compact.uniq
    @cweights["FE_NORMAL"] = @ctotal_babies.collect{|baby| baby.person_id if ((baby.birth_weight.to_i >= 2500 && baby.birth_weight.to_i <= 4500) rescue false) && baby.gender.match(/F/i)}.compact.uniq
    @cweights["FE_HIGH"] = @ctotal_babies.collect{|baby| baby.person_id if ((baby.birth_weight.to_i > 4500) rescue false) && baby.gender.match(/F/i)}.compact.uniq
    @cweights["FE_UNKNOWN"] = (@cgender["FEMALES"] - (@cweights["FE_LOW"] + @cweights["FE_NORMAL"] + @cweights["FE_HIGH"])).uniq
    
    # for the report drill down
    result = {}
    result["discharges"] = @discharge_outcome
    result["deliveries"] = @delivery_mode
    result["gender"] = @gender
    result["admissions"] = @total_admissions
    result["apgar1"] = @apgar1
    result["apgar2"] = @apgar2
    result["total_babies_born"] = @total_babies_born
    result["birth_report_status"] = @birth_report_status
    result["delivery_weeks"] = @delivery_weeks

    #cumulative figures
    result["cdischarges"] = @cdischarge_outcome
    result["cdeliveries"] = @cdelivery_mode
    result["cgender"] = @cgender
    result["cadmissions"] = @ctotal_admissions
    result["capgar1"] = @capgar1
    result["capgar2"] = @capgar2
    result["ctotal_babies_born"] = @ctotal_babies_born
    result["cbirth_report_status"] = @cbirth_report_status
    result["cdelivery_weeks"] = @cdelivery_weeks

    session[:drill_down_data] = result
    
    render :layout => false
  end

  def print_csv
    
    csv_arr = params["print_string"].split(",,")

    csv_string = ""

    csv_arr.each do |row|

      csv_string +=  "#{row}\n"

    end

    send_data(csv_string,
      :type => 'text/csv; charset=utf-8;',
      :stream=> false,
      :disposition => 'inline',
      :filename => "babies_matrix.csv") and return
  end

end
