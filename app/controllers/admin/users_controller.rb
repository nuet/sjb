class Admin::UsersController < Admin::BaseController

  before_action :set_user, only: [:show, :edit, :update, :destroy,:local,:risk_unlock,:service,:update_concern,:update_area,:update_power]

  def index
    if !current_user.have_power('user_manage')
      redirect_to power_admin_dashboard_index_path
    end
    @users=User.where('1=1').page(params[:page]).per(10)
  end


  def show
    if !current_user.have_power('user_manage')
      redirect_to power_admin_dashboard_index_path
    end
  end

  # GET /users/new
  def new
    @user = User.new
  end

  # GET /users/1/edit
  def edit
  end

  def create
    @user=User.new(user_params)
    @user.name=@user.login
    @user.profile_id=1
    User.transaction do
      if @user.save
        if UserPower.new(user:@user).save && UserArea.new(user:@user).save
          redirect_to admin_user_path(@user)
        end
      end
    end
  end

  def update
    User.transaction do
      respond_to do |format|
        if @user.update(user_params)
          format.html {redirect_to admin_users_path, notice: 'successfully updated'}
          format.json {render :show, status: :ok, location: @loan}
        else
          format.html { render :edit }
          format.json { render json: @loan.errors, status: :unprocessable_entity }
        end
      end
    end
  end

  def update_area
    @user.user_area.update(params.require(:area).permit!)
    render json:{code:1}
  end

  def update_power
    @user.user_power.update(params.require(:power).permit!)
    render json:{code:1}
  end

  private
  # Use callbacks to share common setup or constraints between actions.
  def set_user
    @user = User.find(params[:id])
  end

  # Never trust parameters from the scary internet, only allow the white list through.
  def user_params
    params.require(:user).permit!
  end
end