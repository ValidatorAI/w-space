migrate:
	bin/rails db:migrate
run:
	rm -f tmp/pids/server.pid
	bin/rails server
stop:
	@if [ -f tmp/pids/server.pid ]; then \
		kill -9 $$(cat tmp/pids/server.pid) 2>/dev/null || true; \
		rm -f tmp/pids/server.pid; \
	fi
	@fuser -k 3000/tcp 2>/dev/null || true
	@pkill -f "[b]in/rails server|[p]uma.*3000" 2>/dev/null || true
	@echo "Server stopped."
tests:
	bin/rails test
PROFILE ?= workspace

profile:
	./to-profile-dist.sh $(PROFILE) -o "/home/siavash/Documents/codes/Pavel/'w profiles'/$(PROFILE)" -r https://github.com/ValidatorAI/$(PROFILE).git -V 0.0.1 --force

install-profile:
	 HERMES_HOME=/tmp/disttest hermes profile install /home/siavash/Documents/codes/Pavel/'w profiles'/$(PROFILE) -y 
db-reset:
	bin/rails db:reset
db-reset-clean:
	bin/rails db:drop db:create db:schema:load
