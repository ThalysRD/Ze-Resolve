-- Schema inicial SQLite, gerado do modelo SQLAlchemy. Não execute sobre um banco já populado.

CREATE TABLE auth_attempts (
	"key" VARCHAR(64) NOT NULL, 
	window_started_at DATETIME NOT NULL, 
	count INTEGER NOT NULL, 
	PRIMARY KEY ("key")
);

CREATE TABLE categories (
	id INTEGER NOT NULL, 
	name VARCHAR(80) NOT NULL, 
	PRIMARY KEY (id), 
	UNIQUE (name)
);

CREATE TABLE schema_revisions (
	version VARCHAR(40) NOT NULL, 
	applied_at DATETIME NOT NULL, 
	PRIMARY KEY (version)
);

CREATE TABLE users (
	id INTEGER NOT NULL, 
	name TEXT NOT NULL, 
	email TEXT NOT NULL, 
	email_lookup VARCHAR(64) NOT NULL, 
	phone TEXT NOT NULL, 
	role VARCHAR(20) NOT NULL, 
	password_hash VARCHAR(255) NOT NULL, 
	is_active BOOLEAN NOT NULL, 
	email_verified_at DATETIME, 
	closed_at DATETIME, 
	terms_version VARCHAR(30), 
	terms_accepted_at DATETIME, 
	PRIMARY KEY (id), 
	CHECK (role IN ('cliente', 'profissional'))
);

CREATE UNIQUE INDEX ix_users_email_lookup ON users (email_lookup);

CREATE TABLE account_actions (
	id INTEGER NOT NULL, 
	user_id INTEGER NOT NULL, 
	actor VARCHAR(100) NOT NULL, 
	action VARCHAR(30) NOT NULL, 
	reason TEXT NOT NULL, 
	created_at DATETIME NOT NULL, 
	PRIMARY KEY (id), 
	FOREIGN KEY(user_id) REFERENCES users (id)
);

CREATE INDEX ix_account_actions_user_id ON account_actions (user_id);

CREATE TABLE account_challenges (
	digest VARCHAR(64) NOT NULL, 
	user_id INTEGER NOT NULL, 
	purpose VARCHAR(30) NOT NULL, 
	expires_at DATETIME NOT NULL, 
	consumed_at DATETIME, 
	PRIMARY KEY (digest), 
	FOREIGN KEY(user_id) REFERENCES users (id)
);

CREATE INDEX ix_account_challenges_user_id ON account_challenges (user_id);

CREATE TABLE addresses (
	id INTEGER NOT NULL, 
	user_id INTEGER NOT NULL, 
	label TEXT NOT NULL, 
	postal_code TEXT NOT NULL, 
	street TEXT NOT NULL, 
	number TEXT NOT NULL, 
	complement TEXT NOT NULL, 
	neighborhood TEXT NOT NULL, 
	city TEXT NOT NULL, 
	state TEXT NOT NULL, 
	is_default BOOLEAN NOT NULL, 
	is_active BOOLEAN NOT NULL, 
	PRIMARY KEY (id), 
	FOREIGN KEY(user_id) REFERENCES users (id)
);

CREATE INDEX ix_addresses_user_id ON addresses (user_id);

CREATE TABLE auth_tokens (
	digest VARCHAR(64) NOT NULL, 
	user_id INTEGER NOT NULL, 
	expires_at DATETIME NOT NULL, 
	original_expires_at DATETIME NOT NULL, 
	issued_at DATETIME NOT NULL, 
	revoked_at DATETIME, 
	PRIMARY KEY (digest), 
	FOREIGN KEY(user_id) REFERENCES users (id)
);

CREATE INDEX ix_auth_tokens_user_id ON auth_tokens (user_id);

CREATE TABLE mail_deliveries (
	id INTEGER NOT NULL, 
	user_id INTEGER NOT NULL, 
	recipient TEXT NOT NULL, 
	subject VARCHAR(120) NOT NULL, 
	body TEXT NOT NULL, 
	created_at DATETIME NOT NULL, 
	retry_at DATETIME NOT NULL, 
	attempts INTEGER NOT NULL, 
	leased_until DATETIME, 
	completed_at DATETIME, 
	PRIMARY KEY (id), 
	FOREIGN KEY(user_id) REFERENCES users (id)
);

CREATE INDEX ix_mail_deliveries_user_id ON mail_deliveries (user_id);

CREATE TABLE professionals (
	id INTEGER NOT NULL, 
	category_id INTEGER NOT NULL, 
	bio TEXT NOT NULL, 
	city VARCHAR(100) NOT NULL, 
	hourly_rate_cents INTEGER NOT NULL, 
	visit_fee_cents INTEGER, 
	latitude FLOAT, 
	longitude FLOAT, 
	public_name VARCHAR(100) NOT NULL, 
	latitude_private TEXT, 
	longitude_private TEXT, 
	is_available BOOLEAN NOT NULL, 
	PRIMARY KEY (id), 
	CHECK (hourly_rate_cents >= 0), 
	CONSTRAINT ck_professionals_visit_fee_cents CHECK (visit_fee_cents IS NULL OR visit_fee_cents BETWEEN 0 AND 10000000), 
	CHECK (latitude IS NULL OR latitude BETWEEN -90 AND 90), 
	CHECK (longitude IS NULL OR longitude BETWEEN -180 AND 180), 
	CHECK ((latitude IS NULL AND longitude IS NULL) OR (latitude IS NOT NULL AND longitude IS NOT NULL)), 
	FOREIGN KEY(id) REFERENCES users (id), 
	FOREIGN KEY(category_id) REFERENCES categories (id)
);

CREATE INDEX ix_professionals_category_id ON professionals (category_id);

CREATE INDEX ix_professionals_latitude ON professionals (latitude);

CREATE TABLE socket_leases (
	id VARCHAR(64) NOT NULL, 
	user_id INTEGER NOT NULL, 
	expires_at DATETIME NOT NULL, 
	PRIMARY KEY (id), 
	FOREIGN KEY(user_id) REFERENCES users (id)
);

CREATE INDEX ix_socket_leases_expires_at ON socket_leases (expires_at);

CREATE INDEX ix_socket_leases_user_id ON socket_leases (user_id);

CREATE TABLE availability_slots (
	id INTEGER NOT NULL, 
	professional_id INTEGER NOT NULL, 
	starts_at DATETIME NOT NULL, 
	ends_at DATETIME NOT NULL, 
	is_active BOOLEAN NOT NULL, 
	created_at DATETIME NOT NULL, 
	PRIMARY KEY (id), 
	CHECK (ends_at > starts_at), 
	FOREIGN KEY(professional_id) REFERENCES professionals (id)
);

CREATE INDEX ix_availability_professional_start ON availability_slots (professional_id, starts_at);

CREATE TABLE push_devices (
	digest VARCHAR(64) NOT NULL, 
	user_id INTEGER NOT NULL, 
	session_digest VARCHAR(64) NOT NULL, 
	token TEXT NOT NULL, 
	is_active BOOLEAN NOT NULL, 
	PRIMARY KEY (digest), 
	FOREIGN KEY(user_id) REFERENCES users (id), 
	FOREIGN KEY(session_digest) REFERENCES auth_tokens (digest)
);

CREATE INDEX ix_push_devices_session_digest ON push_devices (session_digest);

CREATE INDEX ix_push_devices_user_id ON push_devices (user_id);

CREATE TABLE service_requests (
	id INTEGER NOT NULL, 
	client_id INTEGER NOT NULL, 
	professional_id INTEGER NOT NULL, 
	slot_id INTEGER, 
	visit_fee_cents INTEGER, 
	title TEXT NOT NULL, 
	description TEXT NOT NULL, 
	address TEXT NOT NULL, 
	scheduled_at DATETIME NOT NULL, 
	duration_minutes INTEGER NOT NULL, 
	status VARCHAR(20) NOT NULL, 
	hold_expires_at DATETIME, 
	cancellation_reason VARCHAR(300), 
	cancelled_by INTEGER, 
	created_at DATETIME NOT NULL, 
	PRIMARY KEY (id), 
	CHECK (client_id != professional_id), 
	CHECK (duration_minutes BETWEEN 30 AND 480), 
	CONSTRAINT ck_service_requests_visit_fee_cents CHECK (visit_fee_cents IS NULL OR visit_fee_cents BETWEEN 0 AND 10000000), 
	CHECK (status IN ('pendente','aceita','em_andamento','concluida','cancelada','recusada')), 
	FOREIGN KEY(client_id) REFERENCES users (id), 
	FOREIGN KEY(professional_id) REFERENCES professionals (id), 
	FOREIGN KEY(slot_id) REFERENCES availability_slots (id), 
	FOREIGN KEY(cancelled_by) REFERENCES users (id)
);

CREATE INDEX ix_service_requests_client_id ON service_requests (client_id);

CREATE INDEX ix_service_requests_hold_expires_at ON service_requests (hold_expires_at);

CREATE INDEX ix_service_requests_professional_id ON service_requests (professional_id);

CREATE INDEX ix_service_requests_status ON service_requests (status);

CREATE UNIQUE INDEX uq_service_requests_occupied_slot ON service_requests (slot_id) WHERE slot_id IS NOT NULL AND status IN ('pendente','aceita','em_andamento','concluida');

CREATE TABLE messages (
	id INTEGER NOT NULL, 
	request_id INTEGER NOT NULL, 
	sender_id INTEGER NOT NULL, 
	body TEXT NOT NULL, 
	client_message_id VARCHAR(64), 
	created_at DATETIME NOT NULL, 
	PRIMARY KEY (id), 
	UNIQUE (sender_id, client_message_id), 
	FOREIGN KEY(request_id) REFERENCES service_requests (id), 
	FOREIGN KEY(sender_id) REFERENCES users (id)
);

CREATE INDEX ix_messages_request_id ON messages (request_id);

CREATE TABLE request_events (
	id INTEGER NOT NULL, 
	request_id INTEGER NOT NULL, 
	user_id INTEGER NOT NULL, 
	kind VARCHAR(40) NOT NULL, 
	body TEXT NOT NULL, 
	created_at DATETIME NOT NULL, 
	read_at DATETIME, 
	PRIMARY KEY (id), 
	FOREIGN KEY(request_id) REFERENCES service_requests (id), 
	FOREIGN KEY(user_id) REFERENCES users (id)
);

CREATE INDEX ix_request_events_request_id ON request_events (request_id);

CREATE INDEX ix_request_events_user_id ON request_events (user_id);

CREATE TABLE reviews (
	id INTEGER NOT NULL, 
	request_id INTEGER NOT NULL, 
	rating INTEGER NOT NULL, 
	comment TEXT NOT NULL, 
	created_at DATETIME NOT NULL, 
	PRIMARY KEY (id), 
	CHECK (rating BETWEEN 1 AND 5), 
	UNIQUE (request_id), 
	FOREIGN KEY(request_id) REFERENCES service_requests (id)
);

CREATE TABLE event_deliveries (
	event_id INTEGER NOT NULL, 
	device_digest VARCHAR(64) NOT NULL, 
	session_digest VARCHAR(64) NOT NULL, 
	attempts INTEGER NOT NULL, 
	retry_at DATETIME NOT NULL, 
	leased_until DATETIME, 
	completed_at DATETIME, 
	PRIMARY KEY (event_id, device_digest), 
	FOREIGN KEY(event_id) REFERENCES request_events (id), 
	FOREIGN KEY(device_digest) REFERENCES push_devices (digest), 
	FOREIGN KEY(session_digest) REFERENCES auth_tokens (digest)
);

CREATE TABLE message_receipts (
	user_id INTEGER NOT NULL, 
	message_id INTEGER NOT NULL, 
	read_at DATETIME NOT NULL, 
	PRIMARY KEY (user_id, message_id), 
	FOREIGN KEY(user_id) REFERENCES users (id), 
	FOREIGN KEY(message_id) REFERENCES messages (id)
);

CREATE TABLE push_deliveries (
	message_id INTEGER NOT NULL, 
	device_digest VARCHAR(64) NOT NULL, 
	session_digest VARCHAR(64) NOT NULL, 
	attempts INTEGER NOT NULL, 
	next_attempt_at DATETIME NOT NULL, 
	lease_until DATETIME, 
	completed_at DATETIME, 
	outcome VARCHAR(40), 
	PRIMARY KEY (message_id, device_digest), 
	FOREIGN KEY(message_id) REFERENCES messages (id), 
	FOREIGN KEY(device_digest) REFERENCES push_devices (digest)
);

CREATE INDEX ix_push_deliveries_next_attempt_at ON push_deliveries (next_attempt_at);

-- Marcador auxiliar autenticado de migração; nunca contém a chave.
CREATE TABLE data_protection_metadata (key VARCHAR(64) PRIMARY KEY, value TEXT NOT NULL);
