classdef TestDaemon < handle
    properties
        prop = 42
        server
    end
    methods
        function obj = TestDaemon(address)
            obj.server = daemon.Daemon(address);
            obj.server.expose(obj, 'set_prop');
            obj.server.expose(obj, 'get_prop');
            obj.server.expose(obj, 'hello');
            obj.server.expose(obj, 'echo');
            obj.server.expose(obj, 'add');
        end

        function result = set_prop(obj, val)
            obj.prop = val;
            result = [];
        end

        function val = get_prop(obj)
            val = obj.prop;
        end

        function result = hello(obj, name)
            result = ['Hello, ' name '!'];
        end

        function result = echo(obj, val)
            result = val;
        end

        function result = add(obj, a, b)
            result = a + b;
        end
    end
end