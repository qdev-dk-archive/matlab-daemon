classdef TestDaemon < handle
    properties
        prop = 42
    end
    methods
        function server = make(obj, address)
            server = daemon.Daemon(address);
            server.expose(obj, 'set_prop');
            server.expose(obj, 'get_prop');
            server.expose(obj, 'hello');
            server.expose(obj, 'echo');
            server.expose(obj, 'add');
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