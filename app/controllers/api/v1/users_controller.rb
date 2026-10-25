module Api
  module V1
    class UsersController < BaseController
      def index
        users = user_repository.all
        render_data(users.map { UserSerializer.call(it) })
      end

      def create
        user = user_repository.create(user_params)
        return render_validation_errors(user) if user.errors.any?

        render_data(UserSerializer.call(user), status: :created)
      end

      def update
        user = user_repository.update(params[:id], user_params)
        return head :not_found unless user
        return render_validation_errors(user) if user.errors.any?

        render_data(UserSerializer.call(user))
      end

      private

      def user_repository = UserRepository.instance

      def user_params
        require_attributes(:user, User::WRITABLE_ATTRIBUTES)
      end
    end
  end
end
