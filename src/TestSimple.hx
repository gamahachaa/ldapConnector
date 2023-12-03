package;
import php.LDAP;
import php.Lib;
import php.NativeArray;

/**
 * ...
 * @author bb
 */
class TestSimple
{

	public function new()
	{

		#if debug
		trace("TestSimple::TestSimple");
		#end

		var ldap = new LDAP();
		//var user = "bbaudry";
		//var pwd = "Saa..t33";
		var user_search = "sp_lleonard";
		var user_cnx = "salt\\ser_quality_mgmt";
		var pwd = "T0Th3T0p";
		//var dn = 'OU=Users,OU=Domain-Users,OU=Domain-Disabled-Objects,DC=ad,DC=salt,DC=ch';
		var dn = 'OU=Domain-Disabled-Objects,DC=ad,DC=salt,DC=ch';
		//var dn = '(|(OU=Users,OU=Domain-Disabled-Objects,DC=ad,DC=salt,DC=ch)(OU=Users,OU=Domain-Users,DC=ad,DC=salt,DC=ch))';
		//'OU=Users,OU=Domain-Users,DC=ad,DC=salt,DC=ch'
		var server = "10.192.114.241";
		var port = 389;
		var domain = "salt";
		var map_username = "sAMAccountName";
		//var domain = "salt";
		//var is_conected = ldap.connect("10.192.114.241", 389);
		var is_conected = ldap.connect(server, port);
		//var map_username = "sAMAccountName";
		//var usename_full = '$domain\\$user';
		var filter = '$map_username=$user_search';
		var attributes = ["mail", "sAMAccountName", "givenName", "sn", "mobile", "company", "l", "division", "department", "directReports", "accountExpires", "msExchUserCulture", "title", "initials", "memberOf"];
		#if debug
		trace("TestSimple::TestSimple::is_conected", is_conected );
		#end
		if (is_conected)
		{
			//ldap.bind();

			var bound = ldap.bind(user_cnx, pwd);
			#if debug
			trace("TestSimple::TestSimple::bound", bound );
			#end
			if (bound)
			{
                try{
				//var search = ldap.search(dn, filter);
				var search = ldap.search(dn, filter);
				#if debug
				trace("TestSimple::TestSimple::search", dn, filter );
				#end
				var entries:NativeArray = ldap.get_entries(search);
				#if debug
				trace("TestSimple::TestSimple::entries", entries );
				#end
				trace("<br/>");
				//var entries:NativeArray = ldap.get_entries(ldap.search(dn, "(objectClass=*)", Lib.toPhpArray(attributes)));
				var data = Lib.hashOfAssociativeArray(entries[0]);
				var attr = "";
				for ( i in attributes)
				{
					attr = i;
					if (!data.exists(i))
					{
						attr = i.toLowerCase();
					}
					trace(attr);
					trace(Lib.hashOfAssociativeArray(data.get(attr)).get('0'));
					trace("<br/>");

				}
				//for (i=>v in data)
				//{
				//if (i.toLowerCase() == "sAMAccountName".toLowerCase())
				//{
				//trace(i, v);
				//trace("<br/>");
				//}
				////trace("\n");
				//}
				//Lib.print(data);
				//trace(data);
				Lib.print("<pre>");
				//Lib.dump(entries);
				Lib.print("</pre>");
				}
				catch (e){
					trace(e);
				}
			}
			else
			{
				trace("could not bind");

			}

		}
	}

}