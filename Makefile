migrate:
	bin/rails db:migrate
run:
	bin/rails server
tests:
	bin/rails test
PROFILE ?= workspace

profile:
	./to-profile-dist.sh $(PROFILE) -o "/home/siavash/Documents/codes/Pavel/'w profiles'/$(PROFILE)" -r https://github.com/ValidatorAI/$(PROFILE).git -V 0.0.1 --force

install-profile:
	 HERMES_HOME=/tmp/disttest hermes profile install /home/siavash/Documents/codes/Pavel/'w profiles'/$(PROFILE) -y 