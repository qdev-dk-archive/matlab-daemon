classdef Client < handle
    properties(Access=private)
        sock
    end
    properties(SetAccess=private)
        connect_address
        timeout = Inf % in milliseconds.
    end
    properties(Dependent)
        remote
    end
    properties(Access=private)
        remote_cache
    end
    methods
        function obj = Client(connect_address)
            obj.connect_address = connect_address;
            obj.make_or_remake_sock();
        end

        function r = get.remote(obj)
            if isempty(obj.remote_cache)
                obj.remote_cache = struct();
                for name = obj.call('rpc.list')
                    if isvarname(name{1})
                        obj.remote_cache.(name{1}) = @(varargin) obj.call(name{1}, varargin{:});
                    end
                end
            end
            r = obj.remote_cache;
        end

        function result = call(obj, name, varargin)
            req = struct();
            req.method = name;
            req.params = varargin;
            obj.sock.send(json.dump(req));
            if ~zmq.wait(obj.sock, obj.timeout)
                obj.make_or_remake_sock();
                error('Server timed out (did not reply in %d ms).', obj.timeout);
            end
            rep = json.load(obj.sock.recv());
            if isfield(rep, 'error')
                error(rep.error);
            end
            result = rep.result;
        end

        function heartbeat(obj, varargin)
            p = inputParser();
            p.addOptional('timeout', 3*1000);
            p.parse(varargin{:});
            old_timeout = obj.timeout;
            cleanup = onCleanup(@()obj.set_timeout(old_timeout));
            obj.timeout = p.Results.timeout;
            obj.call('rpc.heartbeat');
        end

        function set_timeout(obj, timeout)
            obj.timeout = timeout;
        end
    end

    methods(Access=private)

        function make_or_remake_sock(obj)
            obj.sock = zmq.socket('req');
            obj.sock.connect(obj.connect_address);
        end

    end
end
