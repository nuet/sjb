class Admin::BillsController < Admin::BaseController
  def not_pay
    if !current_user.have_power('financial')
      redirect_to power_admin_dashboard_index_path
    end
    conditions={location:current_user.get_locations,first_verify: 'verifypass',basic_verify: 'verifypass',customer_verify: 'verifypass',car_verify: 'verifypass',has_pay: false}
    @loans=Loan.where(conditions).page(params[:page]).per(10)
  end

  def pay
    if !current_user.have_power('financial')
      redirect_to power_admin_dashboard_index_path
    end
    loan=Loan.find(params[:id])

    respond_to do |format|
      if loan.pay
        loan.pay_user_id=current_user.id
        loan.save
        format.html { redirect_to not_pay_admin_bills_path, notice: 'unlock successfully.' }
      else
        format.html { redirect_to not_pay_admin_bills_path, notice: 'unlock faild.' }
      end
    end
  end

  def has_pay
    if !current_user.have_power('input')
      redirect_to power_admin_dashboard_index_path
    end
    conditions={user:current_user,first_verify: 'verifypass',basic_verify: 'verifypass',customer_verify: 'verifypass',car_verify: 'verifypass',has_pay: true}
    @loans=Loan.where(conditions).order(created_at: :desc).page(params[:page]).per(10)
  end

  def has_pay_financial
    if !current_user.have_power('financial')
      redirect_to power_admin_dashboard_index_path
    end
    conditions={location:current_user.get_locations,first_verify: 'verifypass',basic_verify: 'verifypass',customer_verify: 'verifypass',car_verify: 'verifypass',has_pay: true}
    @loans=Loan.where(conditions).order(created_at: :desc).page(params[:page]).per(10)
  end

  def instalment
    if !current_user.have_power('financial')
      redirect_to power_admin_dashboard_index_path
    end

    @loan=Loan.find(params[:id])
  end

  def repay
    if !current_user.have_power('financial')
      redirect_to redirect_back(fallback_location: root_path)
    end

    instalment=Instalment.find(params[:id])

    instalment.has_repay=true
    respond_to do |format|
      if instalment.can_repay
        RepayLog.create({instalment:instalment,balance:instalment.balance,no:'后台提交'})
        format.html { redirect_back(fallback_location: root_path) }
      else
        format.html { redirect_back(fallback_location: root_path) }
      end
    end
  end

  def salesman_report
    if !current_user.have_power('totle_loan')
      redirect_to power_admin_dashboard_index_path
    end
    conditions={}

    start_date = '2016-01-01'
    end_date = DateTime.now

    params[:starttime].present? &&
        start_date = params[:starttime].to_datetime.beginning_of_day

    params[:endtime].present? &&
        end_date = params[:endtime].to_datetime.end_of_day

    conditions.merge!({pass_time: start_date..end_date})

    loans=Loan.where(conditions)


    params[:name].present? &&
        loans=loans.where("id in (select loan_id from basic_messages where zdr='"+params[:name]+"')")


    @loans=loans.page(params[:page]).per(10)
  end

  def performance_report
    if !current_user.have_power('totle_loan')
      redirect_to power_admin_dashboard_index_path
    end
    if request.post?
      conditions={}

      start_date = '2016-01-01'
      end_date = DateTime.now

      params[:starttime].present? &&
          start_date = params[:starttime].to_datetime.beginning_of_day

      params[:endtime].present? &&
          end_date = params[:endtime].to_datetime.end_of_day

      params[:yyb].present? &&
          conditions.merge!({location:params[:yyb]})

      conditions.merge!({pass_time: start_date..end_date})
      conditions.merge!({has_pay: true,location:current_user.get_locations})

      loans=Loan.where(conditions)


      params[:cplx].present? &&
          loans=loans.where("id in (select loan_id from basic_messages where dklx='"+params[:cplx]+"')")



      #交易量
      jyl=BasicMessage.where(loan:loans).sum(:zjkje)

      #交易笔数
      jybs=loans.count


      #借款取数
      dkqx=BasicMessage.where(loan:loans).sum('dkqx+0')

      #抵押笔数
      dy_jybs=loans.where("id in (select loan_id from basic_messages where dyzy='抵押')").count

      #抵押金额
      dy_jyl=BasicMessage.where(loan:loans,dyzy:'抵押').sum(:zjkje)

      #质押笔数
      zy_jybs=loans.where("id in (select loan_id from basic_messages where dyzy='质押')").count

      #质押金额
      zy_jyl=BasicMessage.where(loan:loans,dyzy:'质押').sum(:zjkje)

      #新增人数
      xzbs=loans.where("id in (select loan_id from basic_messages where dkxs='新增')").count

      #新增金额
      xzje=BasicMessage.where(loan:loans,dkxs:'新增').sum(:zjkje)

      #贷款余额
      dkye=Instalment.where(has_repay: false).sum(:bj)

      #贷款人数
      dkrs=loans.group(:idcard).count.count


      render json:{code:1,data:{jybs:jybs,jyl:jyl,dkqx:dkqx,dy_jybs:dy_jybs,dy_jyl:dy_jyl,
                                zy_jybs:zy_jybs,zy_jyl:zy_jyl,xzbs:xzbs,xzje:xzje,dkye:dkye,dkrs:dkrs}}
    end
  end

end