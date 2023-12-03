package ;
import haxe.Json;
import haxe.ds.StringMap;
import php.LDAP;
import php.Lib;
import php.NativeArray;
import php.Syntax;
import php.types.ILdapConfig;

/**
 * ...
 * @author bbaudry
 */
class TestHardCoded
{

	public function new(config:php.types.ILdapConfig)
	{
		//hardTrace(config);
		toJson(config);
	}
	function toJson(config:php.types.ILdapConfig)
	{
		var o = new StringMap<Dynamic>();
		//config = new ConfigSalt();
		//var dn = 'OU=Users,OU=Domain-Users,DC=ad,DC=salt,DC=ch';
		//var dn = 'CN=qook,OU=Users,OU=Domain-Users,DC=ad,DC=salt,DC=ch';
		var ldap = new LDAP();
		var user = "bbaudry";
		//var domain = "salt";
		//var is_conected = ldap.connect("10.192.114.241", 389);
		var is_conected = ldap.connect(config.server, config.port);
		//var map_username = "sAMAccountName";
		var usename_full = '${config.domain}\\$user';
		var filter = '${config.map_username}=$user';
		//var attributes = ["mail", "sAMAccountName", "givenName", "sn", "mobile", "company", "l", "division", "department", "directReports", "accountExpires", "msExchUserCulture", "title", "initials", "memberOf"];

		if (is_conected)
		{
			//ldap.bind();
			ldap.bind(usename_full, "T33..saa");

			var entries:NativeArray = ldap.get_entries(ldap.search(config.dn, filter, Lib.toPhpArray(config.attributes)));
			//var entries:NativeArray = ldap.get_entries(ldap.search(dn, "(objectClass=*)", Lib.toPhpArray(attributes)));
			var data = Lib.hashOfAssociativeArray(entries["0"]);
			for (k in config.attributes)
			{
				
				//trace(k);
				var val:NativeArray = data.get(k.toLowerCase());
				Lib.println("<br>---<br>");
				//trace( val );
				if (Syntax.strictEqual(val['count'], 1))
				{
					//trace("Single value");
					//trace(val['0']);
					o.set(k,val['0']);
					
				}
				else
				{
					//trace("more " + k);
					var query = new StringMap<Dynamic>();
					
					for (j in val )
					{
						if (Std.is(j, Int)) continue;
						var q = Helper.getObjectFromQuery(j);
						trace(j);
						trace(q);
						var t = Helper.getArrayFromQuery(j);
						trace(t);
						//if ( q.exists("DC") )
						//{
							//if (!dc.exists(q.get("DC")))
								//dc.set()
						//}
						//trace(Std.is(j, Int));
						//trace(q.get("DC"));
						//var dc:String = q.get("DC");
						//var ou:String = q.get("OU");
						//var cn:String = q.get("CN");
						var map:StringMap<Dynamic>;
						if (!query.exists(q.get("DC")))
						{
							map = new StringMap<Dynamic>();
							query.set( q.get("DC"), map );
						}
						else{
							map = query.get(q.get("DC"));
							//var cnTab:Array<String>;
							if (!map.exists(q.get("OU")))
							{
								//cnTab = [cn];
								map.set(q.get("OU"), [q.get("CN")]);
							}
							else{
								map.get(q.get("OU")).push(q.get("CN"));
							}
						}
						//if(!query.get(dc).exists(ou)) {
							//query.get(dc).set(ou, [cn]);
						//}
						//else if(query.get(dc).get(ou).indexOf(cn) == -1) {
							//query.get(dc).get(ou).push(cn);
						//}
						//trace(q.get("OU"));
						//trace(q.get("CN"));
						
						//Lib.println("<br>###<br>");
						//tab.push();
					}
					o.set(k, query);
					//trace(query);
				}
				//trace( val );
				//Lib.println("<br>--------------------------------<br>");
			}
			trace(o);
			Lib.dump(Json.stringify(o));
			//trace(entries['data'].get("memberOf"));
			ldap.close();
		}
		else
		{
			trace("not connected");
		}
	}
	function hardTrace(config:php.types.ILdapConfig)
	{
		//config = new ConfigSalt();
		//var dn = 'OU=Users,OU=Domain-Users,DC=ad,DC=salt,DC=ch';
		//var dn = 'CN=qook,OU=Users,OU=Domain-Users,DC=ad,DC=salt,DC=ch';
		var ldap = new LDAP();
		var user = "bbaudry";
		//var domain = "salt";
		//var is_conected = ldap.connect("10.192.114.241", 389);
		var is_conected = ldap.connect(config.server, config.port);
		//var map_username = "sAMAccountName";
		var usename_full = '${config.domain}\\$user';
		var filter = '${config.map_username}=$user';
		//var attributes = ["mail", "sAMAccountName", "givenName", "sn", "mobile", "company", "l", "division", "department", "directReports", "accountExpires", "msExchUserCulture", "title", "initials", "memberOf"];

		if (is_conected)
		{
			//ldap.bind();
			ldap.bind(usename_full, "T33..saa");

			var entries:NativeArray = ldap.get_entries(ldap.search(config.dn, filter, Lib.toPhpArray(config.attributes)));
			//var entries:NativeArray = ldap.get_entries(ldap.search(dn, "(objectClass=*)", Lib.toPhpArray(attributes)));
			var data = Lib.hashOfAssociativeArray(entries["0"]);
			for (k in config.attributes)
			{
				trace(k);
				var val:NativeArray = data.get(k.toLowerCase());
				Lib.println("<br>---<br>");
				//trace( val );
				if (Syntax.strictEqual(val['count'], 1))
				{
					trace("Single value");
					trace(val['0']);
				}
				else
				{
					trace("more more more" + k, k == null);
					for (j in val )
					{
						//trace(Helper.getObjectFromQuery(j));
						trace(j);
						Lib.println("<br>###<br>");
					}
				}
				//trace( val );
				Lib.println("<br>--------------------------------<br>");
			}
			//trace(entries['data'].get("memberOf"));
			ldap.close();
		}
		else
		{
			trace("not connected");
		}
	}

}

class Helper
{
	public function new() {}
	public static inline function getObjectFromQuery(query:String)
	{
		var tmp = query.split(",");
		tmp.reverse();
		var r = [];
		var m = new Map<String, String>();
		for (i in tmp)
		{
			r = i.split("=");

			if (m.exists(r[0]))
			{
				m.set(r[0], m.get(r[0]) + "." + r[1] );
			}
			else
			{
				m.set(r[0], r[1]);
			}
		}
		return m;
	}
	public static inline function getArrayFromQuery(query:String)
	{
		var tmp = query.split(",");
		tmp.reverse();
		trace(tmp);
		var r = [];
		var m = [];
		for (i in tmp)
		{
			r = i.split("=");
			m.push(r[1]);
//
			//if (m.indexOf(r[0]) == -1)
			//{
				//m.set(r[0], m.get(r[0]) + "." + r[1] );
			//}
			//else
			//{
				//m.set(r[0], r[1]);
			//}
		}
		return m;
	}
}
