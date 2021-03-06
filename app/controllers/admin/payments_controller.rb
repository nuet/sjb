class Admin::PaymentsController < Admin::BaseController

  def index
    conditions = {}
    params[:name].present? &&
        conditions.merge!({user: User.find_by_login(params[:name])})
    params[:status].present? &&
        conditions.merge!({status: params[:status]})
    params[:date].present? &&
        conditions.merge!({created_at:DateTime.parse(params[:date]).all_day})
    params[:payment_type].present? &&
        conditions.merge!({payment_type: params[:payment_type]})

    @payments = Payment.where(conditions).page(params[:page]).per(10)
  end

  def sh_fail
    @payment = Payment.find(params[:id])
    if @payment.status==0
      @payment.status=2
      if @payment.payment_type==false
          if @payment.category=='反点提现'
            @payment.rebate_fail
          elsif @payment.category=='时时彩反点'
            @payment.ssc_rebate_fail
          else
            @payment.pay
          end
      else
      end
      @payment.save
    end
    respond_to do |format|
      format.html { redirect_back(fallback_location: admin_payments_path) }
      format.json { head :no_content }
    end
  end

  def sh_success
    @payment = Payment.find(params[:id])
    if @payment.status==0
      @payment.status=1
      @payment.pay if @payment.payment_type==true
      @payment.save
    end
    respond_to do |format|
      format.html { redirect_back(fallback_location: admin_payments_path) }
      format.json { head :no_content }
    end
  end



  def destroy
    @payment = Payment.find(params[:id])
    @payment.destroy
    respond_to do |format|
      format.html { redirect_to admin_payments_path, notice: 'User was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

end