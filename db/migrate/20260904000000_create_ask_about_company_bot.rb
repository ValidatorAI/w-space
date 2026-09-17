class CreateAskAboutCompanyBot < ActiveRecord::Migration[8.0]
  def up
    return unless table_exists?(:users)

    FirstRun.ensure_company_bot! if User.exists?
  end

  def down
    User.where(email_address: FirstRun::COMPANY_BOT_EMAIL).find_each(&:destroy)
  end
end
