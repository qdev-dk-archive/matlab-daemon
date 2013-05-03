classdef Daemon < handle
    properties(Access=private)
        exposed
        sock
        last_alert
    end
    properties(SetAccess=private)
        bind_address
    end
    properties
        smtp_server
        alert_email
        alert_on_exceptions = true
        minimum_time_between_alerts = 10*60 % Default is 10 minutes.
        daemon_email
        daemon_name = 'daemon'
        debug_enabled = false
    end
    methods
        function obj = Daemon(address)
            obj.exposed = containers.Map();
            obj.bind_address = address;
            obj.sock = zmq.socket('rep');
            obj.sock.bind(address);
            obj.expose_func(@()obj.exposed.keys(), 'rpc.list');
        end

        function delete(obj)
            disp deleted;
        end

        function serve_once(obj, varargin)
            p = inputParser();
            p.addOptional('timeout', Inf);
            p.parse();
            timeout = p.Result.timeout;
            if ~zmq.wait(obj.sock, timeout)
                return;
            end
            msg = obj.sock.recv();
            if obj.debug_enabled
                disp(['req ' msg]);
            end
            rep = struct();
            try
                parsed = json.load(msg);
                if iscell(parsed.params)
                    params = parsed.params;
                else
                    params = num2cell(parsed.params);
                end
                rep.result = obj.call(parsed.method, params);
            catch err
                rep.error = err.message;
                if obj.alert_on_exceptions
                    obj.send_alert_from_exception('Exception occured', err);
                end
                disp(getReport(err));
            end
            rmsg = json.dump(rep);
            if obj.debug_enabled
                disp(['rep ' rmsg]);
            end
            obj.sock.send(rmsg);
        end

        function serve_period(obj, period)
            serve_start = tic();
            keep_going = true;
            while keep_going
                time_left = max(0, period - toc(serve_start));
                obj.serve_once(time_left*1000);
                if toc(serve_start) > period
                    keep_going = false;
                end
            end
        end

        function serve_forever(obj)
            while true
                obj.serve_once();
            end
        end

        function expose(obj, target, method_name, varargin)
            p = inputParser();
            p.addOptional('name', method_name);
            p.parse(varargin{:});
            name = p.Result.name;
            obj.expose_func(@(varargin) target.(method_name)(varargin{:}), name);
        end

        function expose_func(obj, func, name)
            if obj.exposed.isKey(name)
                error('A function named %s has already been exposed.', name);
            end
            obj.exposed(name) = func;
        end

        function send_alert(obj, subject, body)
            if isempty(obj.alert_email)
                return
            end
            if isempty(obj.last_alert) || toc(obj.last_alert) > obj.minimum_time_between_alerts
                smtp = 'mail';
                if ~isempty(obj.smtp_server)
                    smtp = obj.smtp_server;
                end
                if ~isempty(obj.daemon_email)
                    from = obj.daemon_email;
                else
                    [~, hostname] = system('hostname');
                    from = sprintf('%s@%s', obj.daemon_name, hostname);
                end
                try
                    % TODO, change back settings.
                    setpref('Internet','SMTP_Server', smtp);
                    setpref('Internet','E_mail', from);
                    sendmail(obj.alert_email, subject, body);
                catch err
                    warning(['Could not send email: ' err.message]);
                end
                obj.last_alert = tic();
            end
        end

        function send_alert_from_exception(obj, subject, err)
            obj.send_alert(subject, ...
                getReport(err, 'extended', 'hyperlinks', 'off'));
        end
    end
    methods(Access=private)
        function result = call(obj, method, params)
            if ~obj.exposed.isKey(method)
                error('No such method: %s', msg_parsed.method);
            end
            func = obj.exposed(method);
            result = func(params{:});
        end
    end
end
