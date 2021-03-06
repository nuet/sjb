class Admin::RefereesController < Admin::BaseController
  before_action :set_user, only: [:show,:settlement,:update]

  def index
    # conditions={referee:users.group(referee)}
    conditions="not referee is null and not referee = ''"

    if params[:login].present?
      user=User.find_by_login(params[:login])
      if user.present?
        conditions=" referee = '#{user.id}'"
      else
        conditions=" referee = '0'"
      end
    end

    @users=User.select(" referee")
               .where(conditions)
               .group("referee").page(params[:page]).per(10)

  end

  def ssc
    sql='user_id in(select user_id from ssc_journal_logs group by user_id) or journal>0'
    @journals=SscJournal.where(sql).page(params[:page]).per(10)
  end

  private
  def set_user
    @user = User.find(params[:id])
  end
end