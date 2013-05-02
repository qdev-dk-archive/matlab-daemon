classdef Client < handle
    properties(Access=private)
        sock
    end
    properties(SetAccess=private)
        connect_address
    end
    methods
        function obj = Client(connect_address)
            obj.connect_address = connect_address;
            obj.sock = zmq.socket('req');
            obj.sock.connect(connect_address);
        end

        function result = call(obj, name, varargin)
            req = struct();
            req.method = name;
            req.params = varargin;
            obj.sock.send(json.dump(req));
            rep = json.load(obj.sock.recv());
            if isfield(rep, 'error')
                error(rep.error);
            end
            result = rep.result;
        end
    end
end