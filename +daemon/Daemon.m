classdef Daemon < handle
    properties(Access=private)
        exposed = containers.Map()
        sock
        last_warning
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
        debug_enabled = false
    end
    methods
        function obj = Daemon(address)
            obj.bind_address = address;
            obj.sock = zmq.socket(zmq.Type.rep);
            obj.sock.bind(address);
        end

        function serve_once(obj, varargin)
            switch length(varargin)
            case 0
                timeout = Inf;
            case 1
                timeout = varargin{1};
            otherwise
                error('Too many parameters.');
            end
            if ~zmq.wait(obj.sock, timeout)
                return;
            end
            msg = obj.sock.recv();
            if obj.debug_enabled
                disp(['req ' msg]);
            end
            rep = struct();
            try
                msg_parsed = json.load(msg);
                func = obj.exposed(msg_parsed.method);
                if iscell(msg_parsed.params)
                    params = msg_parsed.params;
                else
                    params = num2cell(msg_parsed.params);
                end
                switch nargout(func)
                case 0
                    func(params{:});
                    rep.result = [];
                otherwise
                    rep.result = func(params{:});
                end
            catch err
                rep.error = err.message;
                if obj.alert_on_exceptions
                    obj.send_alert_from_exception('Exception occured', err);
                end
                if obj.debug_enabled
                    disp(getReport(err));
                end
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
                t = max(0, period - toc(serve_start));
                obj.serve_once(t*1000);
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
            switch length(varargin)
            case 0
                name = method_name;
            case 1
                name = varargin{1};
            otherwise
                error('Too many parameters.');
            end
            obj.expose_func(@(vararg) target.(method_name)(vararg{:}), name);
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
            smtp = 'mail';
            if ~isempty(obj.smtp_server)
                smtp = obj.smtp_server;
            end
            if ~isempty(obj.daemon_email)
                from = obj.daemon_email;
            else
                [~, hostname] = system('hostname');
                from = sprintf('daemon@%s', hostname);
            end
            try
                % TODO, change back settings.
                setpref('Internet','SMTP_Server', smtp);
                setpref('Internet','E_mail', from);
                sendmail(obj.alert_email, subject, body);
            catch err
                warning(['Could not send email: ' err.message]);
            end
        end

        function send_alert_from_exception(obj, subject, err)
            if isempty(obj.last_warning) || toc(obj.last_warning) > obj.minimum_time_between_alerts
                obj.send_alert(subject, ...
                    getReport(err, 'extended', 'hyperlinks', 'off'));
                obj.last_warning = tic();
            end
        end
    end
end