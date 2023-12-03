package;
import haxe.Exception;
import haxe.Json;
import haxe.Utf8;
import haxe.crypto.Base64;
import haxe.ds.Map;
import haxe.ds.StringMap;
import haxe.io.Bytes;
import haxe.io.Encoding;
import ldap.Attributes;
import ldap.Params;
import ldap.Results;
import php.ConfigSalt;
import php.Global;
import php.LdapConnector;
import php.Lib;
import php.SuperGlobal;
import regex.ExpReg;
import string.StringUtils;
import string.StringUtils.RGBA;
//import php.Web;
//import sys.FileSystem;
//import sys.io.File;
using StringTools;

//import yaml.Yaml;
/**
 * ...
 * @author
 */
typedef Credentials =
{
	var errored:Bool;
	var user:String;
	var password:String;
}
typedef Searches=
{
	var emails:Array<String>;
	var nts:Array<String>;
	var cns:Array<String>;
	var rawCns:Array<Array<String>>;
	var rejected:Array<String>;
}
class App
{

	var _cnx:php.LdapConnector;
	var _config:ConfigSalt;
	var _cred:Credentials;
	var _result:haxe.ds.StringMap<Dynamic>;
	var _debug:Bool;
	var _attributesType:Array<String>;
	var _params:Map<String, String>;
	var _singleUserAttributes:StringMap<Dynamic>;
	var _thumbnailEncoded:String;
	//var _directReports:Array<StringMap<Dynamic>>;
	//var _peers:Array<StringMap<Dynamic>>;
	//var _boss:StringMap<Dynamic>;

	static var PARAMS_INFO = [
								 Params.DEBUG_PARAM => 'adds some tracing and butyfy variable',
								 Params.MAINSUB_JSON_PARAM => 'Accepts Json encoded with 2 vars : "attr" and "subattr"',
								 Params.ATTR_TYPE_PARAM=>'string "main" or "sub" to force the type of returned attibutes for this query modifying/unifying the default result (main attributes for ${Params.SEARCH_PARAM} or ${Params.USERNAME_PARAM} and sub attibutes for ${Params.DIRECT_REPORT_PARAM}, ${Params.PEERS_PARAM} and ${Params.MAIN_ATTR_PARAM}).',
								 Params.MAIN_ATTR_PARAM=>'string or arry joined as string with "${Params.ATTRIBUTE_SEPARATOR}" separator. To ad AD attributes to main serached "${Params.USERNAME_PARAM}" or "${Params.SEARCH_PARAM}" (if "${Params.ATTR_TYPE_PARAM}" is not set)',
								 Params.SUB_ATTR_PARAM=>'string or arry joined as string with "${Params.ATTRIBUTE_SEPARATOR}" separator. To ad AD attributes to sub searched "${Params.MANAGER_PARAM}", "${Params.PEERS_PARAM}" or "${Params.DIRECT_REPORT_PARAM}"',
								 Params.ATTR_ADD_OR_SET_PARAM=>'Boolean to tell if the additional attributes parameters are added or replacing the default attributes. (default to true, meaning that the "${Params.MAIN_ATTR_PARAM}" or "${Params.SUB_ATTR_PARAM}" are added by default)',
								 Params.DIRECT_REPORT_PARAM=>'Can be either true (if a "${Params.USERNAME_PARAM}" param is set) or a valid DN',
								 Params.PEERS_PARAM=>'Will return array of AD user with "${Params.SUB_ATTR_PARAM}" result by default or "${Params.MAIN_ATTR_PARAM}" if oveeriden by "${Params.ATTR_TYPE_PARAM}"',
								 Params.MANAGER_PARAM=>'Will return single AD user with "${Params.SUB_ATTR_PARAM}". The returned var will be named "${Results.MANAGER_RESULT}"',
								 Params.USERNAME_PARAM=>'Needed when first authorising a user. Need a "${Params.PASSWORD_PARAM}" param in parrallel',
								 Params.TEAM_TL_PARAM=>'Url encoded ";" separated CSV String. When managing the external partners team to tl list. If value is an emtpy string gets it else set'];
	static var RESULTS_INFO = [
								  Results.STATUS_RESULT => 'informs about the queries status',
								  Results.AUTHORIZED_RESULT => 'Boolean. Returns the AD binding of "${Params.USERNAME_PARAM}" with "${Params.PASSWORD_PARAM}"',
								  Results.ATTRIBUTES_RESULT=>'Map of AD attributes for the main searched "username" or "search"',
								  Results.DIRECT_REPORT_RESULT=>'Array of AD users with subattr',
								  Results.PEERS_RESULT=>'Array of AD users with subattr',
								  Results.MANAGER_RESULT=>'Map of AD subattr of the main user searched ("${Params.USERNAME_PARAM}" or "${Params.SEARCH_PARAM}")',
								  Results.TEAM_TL_RESULT=>'Encode url list of team to TL',
								  Results.DETAILS_RESULT=>'Error reporting details',
								  Results.MESSAGE_RESULT=>'Error reporting message'
							  ];

	static inline var TEAMLEADERS_EXTERNAL_PATH:String = "./teams/teams_manager.csv";
	var _thumbnailBytes:Bytes;
	var DEFAULT_BG:String = "FF0000";
	var DEFAULT_TEXT_COLOR: String = "FFFFFF";

	public function new()
	{
		_params = Lib.hashOfAssociativeArray(SuperGlobal._REQUEST);
		_debug = _params.exists(Params.DEBUG_PARAM);
		_config = new ConfigSalt(TEAMLEADERS_EXTERNAL_PATH);
		//
		_singleUserAttributes = null;
		_attributesType = null ;
		// prepare output
		_result = new StringMap<Dynamic>();
		_result.set(Results.AUTHORIZED_RESULT, false);

		// show the api if param Params.DEBUG_PARAM
		if (_debug && Lambda.array(_params).length == 1 || Lambda.array(_params).length == 0)
		{
			info_debug();
		}
		else
		{
			try
			{
				_cnx = new php.LdapConnector( _config );// CONNECTING

				setAdditionalAttributes(_params);

				if (_params.exists(Params.ATTR_TYPE_PARAM))
				{
					_attributesType = _params.get(Params.ATTR_TYPE_PARAM) == "main"? _config.attributes : _config.attributesSubs;
				}

				_cred = getCredentials(_params); //

				if (_cred.errored)
				{
					_result.set(Results.STATUS_RESULT, 'Empty user or password' );
				}
				else
				{

					if (!_cnx.isAuthorised(_cred.user, _cred.password ))
					{
						_result.set(Results.STATUS_RESULT, 'UNAUTHORIZED Wrong password or unknow user ${_cred.user} ${_debug ? _cred.password:""}' );
					}
					else
					{
						_result.set(Results.STATUS_RESULT, "ldap could bind");
						_result.set(Results.AUTHORIZED_RESULT, true);
						/**
						 * Cases : username + _cred.password ->
						 */
						try
						{
							_singleUserAttributes = getUsersAttributes(_params);
							if (_singleUserAttributes == null)
							{
								_result.set(Results.ATTRIBUTES_RESULT, {"error":"No LDAP attributes"});
							}
							else
							{
								_result.set(Results.ATTRIBUTES_RESULT, _singleUserAttributes);
							}
						}
						catch (e)
						{
							#if debug
							trace(e);
							#else
							#end
						}
						if (_params.exists(Params.FINDMANY_PARAM))
						{
							// result is set in the function
							getMany(_params.get(Params.FINDMANY_PARAM), _params.exists(Params.MANAGER_PARAM));

						}
						if (_params.exists(Params.SEARCH_WILD_PARAM))
						{
							wildNTSearch(_params.get(Params.SEARCH_WILD_PARAM));
						}

						if (_params.exists(Params.DIRECT_REPORT_PARAM))
						{

							getDirectReports(_params, _singleUserAttributes );

						}

						if (_params.exists(Params.PEERS_PARAM))
						{
							getPeers();

						}
						if (_params.exists(Params.MANAGER_PARAM))
						{
							getBoss();

						}
						if (_params.exists(Params.TEAM_TL_PARAM))
						{
							var tlList = _params.get(Params.TEAM_TL_PARAM);
							if (tlList != "")
							{
								storeTeamTLList(tlList);
							}
							else
							{
								getTeamList();
							}

						}
						/*if (_params.exists(Params.ATTR_THUMBNAIL) && findUserSearchInParams() !="")
						{
							_thumbnailEncoded = Base64.encode(
													Bytes.ofString(
														StringTools.urlDecode(
															_singleUserAttributes.get(Attributes.thumbnailphoto)
														)));
						}*/

					}

				}

			}
			catch (e:Exception)
			{
				_result.set(Results.STATUS_RESULT, "Exception thrown when logging with " + _cred.user);
				_result.set(Results.DETAILS_RESULT, e.details);
				_result.set(Results.MESSAGE_RESULT, e.message);
			}
		}

		if (_debug)
		{
			//Lib.dump(Json.stringify(_result));
			Lib.dump(Lib.associativeArrayOfHash(_result));

			Lib.println("<br/>");
			if (_params.exists(Params.ATTR_THUMBNAIL))
				Lib.println('<img src="data:image/jpeg;base64,${_thumbnailEncoded}"/>');
			//Lib.println(_thumbnailEncoded);
			Lib.println("<br/>");

		}
		else
		{
			try
			{
				if (_params.exists(Params.ATTR_THUMBNAIL) && findUserSearchInParams() != "")
				{
					generateImageThumbnail();
					//Lib.println(_thumbnailBytes);
				}
				else
				{

					/*if (false && _singleUserAttributes.exists(Attributes.thumbnailphoto))
					{
						_thumbnailEncoded = Base64.encode(
							Bytes.ofString(

							_singleUserAttributes.get(Attributes.thumbnailphoto)
							));
						_singleUserAttributes.set(Attributes.thumbnailphoto, _thumbnailEncoded);
						_result.set(Results.ATTRIBUTES_RESULT , _singleUserAttributes);
					} */

					//_result.set("thnumbnailBase64", _thumbnailEncoded);
					Lib.print(Json.stringify(_result));

				}

			}
			catch (e)
			{
				trace(e);
			}

		}
		_cnx.close();

	}
	function getUsersAttributes(params:Map<String,Dynamic>)
	{
		#if debug
		//trace("App::getUsersAttributes");
		#end
		var r = null;
		var userSearch = findUserSearchInParams();

		if (userSearch == "")
		{
			_result.set(Results.ATTRIBUTES_RESULT, {"error":"Could not get the user to search"});
		}
		else
		{
			r = getSingle(userSearch);
			if (r == null || r == [])
			{
				r = getSingle(userSearch, true);
			}
		}

		return r;
	}

	function getSingle(s:String, ?disabled:Bool=false):Map<String, Dynamic>
	{
		var search = createSearchString(s);
		if (search == "")
		{
			_result.set(Results.STATUS_RESULT, 'NOT FOUND $s');
			_result.set(Results.REJECTED_RESULT, s);
			return null;
		}
		else{
			return  _cnx.getAttributesFromSingle(search, _attributesType, disabled);
		}

	}
	function wildNTSearch(subNt:String)
	{
		//Lib.dump("here3");
		var wildSearch = _cnx.getAttributesFromMultiple(
							 '(|(sAMAccountName=*$subNt*)(cn=*$subNt*)(mail=*$subNt*))',
							 _config.attributes.concat([Attributes.cn])
						 );
//Lib.dump("here4");
		_result.set(
			Results.SEARCH_WILD_PARAM,
			Lambda.map(wildSearch,
					   function(e)
		{
			return [
					   Attributes.mail => e.get(Attributes.mail.toLowerCase()),
					   Attributes.sAMAccountName => e.get(Attributes.sAMAccountName.toLowerCase()),
					   Attributes.cn => e.get(Attributes.cn.toLowerCase()),
					   Attributes.title => e.get(Attributes.title.toLowerCase())];
		}
					  )
		);
		//Lib.dump("here5");
	}
	function getMany(list:String, ?withManager:Bool = false)
	{
		var notFound:Array<String>= [];
		var foundNonActives:Array<StringMap<Dynamic>> = [];
		var searchesNonActive:Searches;
		//bruno.baudry@salt.ch|aron.peter@salt.ch|naerts|sorlando|Nina hagmann|julieta vaz velho|Grzeskiewicz Daria Malgorzata
		var split:Array<String> = list.urlDecode().split(Params.COLLECTION_SEPARATOR);
		var searches:Searches = filterByFormat(split);

		#if debug
		Lib.dump(list);
		Lib.dump(split);
		Lib.dump(searches);
		#end
		
		var foundActiveNonRejected:Array<StringMap<Dynamic>> = _cnx.getAttributesFromMultiple(
					generateSearchString(
						searches.emails,
						searches.nts,
						searches.cns),
					_attributesType
				);
		foundActiveNonRejected = foundActiveNonRejected == null ? []:foundActiveNonRejected;
		var deltaSearchFoundActive:Int = foundActiveNonRejected.length + searches.rejected.length;

		#if debug
		Lib.dump("Here1 " + deltaSearchFoundActive);
		#end
		if ( split.length != deltaSearchFoundActive )
		{
			#if debug
			Lib.dump("Here2");
			#end
			//search in the non active ad domain
			searchesNonActive = filterNonActive(foundActiveNonRejected, searches);

			foundNonActives = _cnx.getAttributesFromMultiple(
								  generateSearchString(
									  searchesNonActive.emails,
									  searchesNonActive.nts,
									  searchesNonActive.cns),
								  null,
								  true
							  );
			foundNonActives = foundNonActives == null ? []: foundNonActives;

			notFound = computeMissingOne(
						   foundNonActives.concat(foundActiveNonRejected),
						   searches.nts,
						   searches.emails,
						   searches.rawCns
					   );

		}

		if (withManager && foundActiveNonRejected.length > 0)
		{
			for (i in foundActiveNonRejected)
			{
				var sam = i.get(Attributes.sAMAccountName.toLowerCase());
				//Lib.dump("sam");
				//Lib.dump(sam);
				var b = _cnx.getBoss(i, null);
				if (b == null)
				{
					b = _cnx.getBoss(i, null, true );
					if (b != null)
					{
						b = _cnx.getAttributesFromMultiple('(|(cn=*${i.get(Attributes.info)}*))')[0];
					}
				}
				//i.set(Results.MANAGER_RESULT, _cnx.getBoss(i,null));
				i.set(Results.MANAGER_RESULT,b);
			}
		}
		_result.set(Results.LEAVERS_RESULT, foundNonActives);
		_result.set(Results.FINDMANY_RESULT, foundActiveNonRejected);
		_result.set(Results.NOT_FOUND_COUNT_RESULT, notFound.length + searches.rejected.length);
		_result.set(Results.REJECTED_RESULT, searches.rejected);
		_result.set(Results.FAILED_FINDMANY, notFound);

		//return foundActiveNonRejected;
	}
	function filterByFormat(tab:Array<String>) :Searches
	{
		var t: Searches =
		{
			emails:[],
			nts:[],
			cns:[],
			rawCns:[],
			rejected:[]
		}
		for (i in tab)
		{
			if ( ExpReg.STRING_TO_REG(ExpReg.EMAIL, "i").match(i))
				t.emails.push(i);
			else if (ExpReg.STRING_TO_REG(ExpReg.SALT_NT, "i").match(i))
				t.nts.push(i);
			else if (ExpReg.STRING_TO_REG(ExpReg.CN, "i").match(i))
			{
				t.cns.push(_cnx.generateANDSearchFromAttributeAndList(i.split(" "), Attributes.cn, true));
				t.rawCns.push(i.split(" "));
			}
			else
				t.rejected.push(i);
		}
		return t;
	}
	function generateSearchString(emails, nts, cns)
	{
		#if debug
		Lib.dump(emails);
		Lib.dump(nts);
		Lib.dump(cns);
		//Lib.dump();
		#end
		var s = _cnx.multipleSearchesOR([
											_cnx.generateORSearchFromAttributeAndList(emails,Attributes.mail),
											_cnx.generateORSearchFromAttributeAndList(nts, Attributes.sAMAccountName ),
											_cnx.multipleSearchesOR(cns)
										]);

		return s;
	}
	function filterNonActive(found:Array<StringMap<Dynamic>>, searched:Searches):Searches
	{
		found = found == null ? []:found;
		var t: Searches =
		{
			emails:[],
			nts:[],
			cns:[],
			rawCns:[],
			rejected:[]
		}

		for (i in searched.emails)
		{
			if ( !Lambda.exists(
				found,
				(e)->(e.get(Attributes.mail.toLowerCase())== i))) t.emails.push(i);
		}
		for (i in searched.nts)
		{
			if (!Lambda.exists(found, (e)->(e.get(Attributes.sAMAccountName.toLowerCase())== i))) t.nts.push(i);
		}

		//trace(t.nts);
		for (i in searched.cns)
		{
			if (!Lambda.exists(found, (e)->(e.get(Attributes.cn.toLowerCase()) == i))) t.cns.push(i);
		}
		return t;
	}
	function computeMissingOne(tab:Array<StringMap<Dynamic>>, nts:Array<String>, emails:Array<String>, cns:Array<Array<String>> )
	{
		var failed = [];
		for (i in nts)
		{
			if (!Lambda.exists(tab, (e)->(return e.get(Attributes.sAMAccountName.toLowerCase()) == i)))
				failed.push(i);
		}
		for (i in emails)
		{
			if (!Lambda.exists(tab, (e)->(return e.get(Attributes.mail.toLowerCase()).toLowerCase() == i.toLowerCase())))
				failed.push(i);
		}
		for (i in cns)
		{
			//trace(i);

			if (!Lambda.exists(tab,
							   function (e)
		{
			//trace(e);
			return Lambda.exists(i,
								 function (el)
			{
				//trace(el);
				return e.get(Attributes.distinguishedName.toLowerCase()).toLowerCase().indexOf(el.toLowerCase()) >-1;
				}
									);
			}))
			failed.push(i.join(" "));
		}
		return failed;
	}

	function setAdditionalAttributes(params:haxe.ds.Map<String, String>)
	{
		var addParams = params.exists(Params.ATTR_ADD_OR_SET_PARAM) ? params.get(Params.ATTR_ADD_OR_SET_PARAM)=="true" :true;
		if (params.exists(Params.MAINSUB_JSON_PARAM))
			_cnx.setAdditionalAttributesFromJsonString( params.get(Params.MAINSUB_JSON_PARAM), addParams);
		else
		{
			if (params.exists( Params.MAIN_ATTR_PARAM ))
				_cnx.setAdditionalAttributesFromStringifiedArray( params.get(Params.MAIN_ATTR_PARAM), addParams );
			if (params.exists(Params.SUB_ATTR_PARAM))
				_cnx.setAdditionalSubattributesFromStringifiedArray( params.get( Params.SUB_ATTR_PARAM ), addParams );
		}

	}

	function getDirectReports(params:haxe.ds.Map<String, String>, attributes:StringMap<Dynamic>):Void
	{
		var directReports = if (attributes == null && params.exists(Params.DIRECT_REPORT_PARAM))
		{
			//seraching direct reports from DN
			_cnx.getDirectReportsFromDN(params.get(Params.DIRECT_REPORT_PARAM).trim().urlDecode(), _attributesType);
		}
		else
		{
			_cnx.getDirectReports(attributes, _attributesType);
		}
		//
		if (directReports == [])
		{
			_result.set(
				Results.STATUS_RESULT,
				_result.get(Results.STATUS_RESULT) + "; No ${Results.DIRECT_REPORT_RESULT} found"
			);
		}
		else _result.set(Results.DIRECT_REPORT_RESULT, directReports);
	}

	//////////////////////////////////////////////////////////////////////
	/**
	 * Use the NT and pswd when checking if user is allowed esle use service credentials.
	 * @param	params
	 * @param	String
	 * @return
	 */
	function getCredentials(params:haxe.ds.Map<String, String>):Credentials
	{
		var user = "";
		var pwd ="";
		if (params.exists(Params.USERNAME_PARAM))
		{
			user = validateUSername(params);
			pwd = validatePwd(params);

		}
		else{
			user = _config.serviceUsername;
			pwd = _config.servicePwd;
		}
		return {user:user, password:pwd, errored: user == "" || pwd == ""};
	}

	function validatePwd(params:haxe.ds.Map<String, String>)
	{
		if (params.exists(Params.PASSWORD_PARAM))
		{
			var p = params.get(Params.PASSWORD_PARAM).trim();
			//_result.set("pwd", p);
			if (params.get(Params.PASSWORD_PARAM).trim() == "")
			{
				_result.set(Results.STATUS_RESULT, 'Cannot connect ${params.get("username")} with an empty password');
				return "";
			}

			var decoded:Bytes = Base64.decode(params.get(Params.PASSWORD_PARAM));
			return decoded.length == 0 ? "": Base64.decode(params.get(Params.PASSWORD_PARAM)).toString();
		}
		else
		{
			_result.set(Results.STATUS_RESULT, 'Cannot connect ${params.get("username")} without password');
			return "";
		}
	}

	function validateUSername(params:haxe.ds.Map<String, String>):String
	{
		if (params.exists(Params.USERNAME_PARAM))
		{
			var u = params.get(Params.USERNAME_PARAM);
			if (ExpReg.STRING_TO_REG(ExpReg.SALT_NT).match(u))
				return params.get(Params.USERNAME_PARAM);
			else
				_result.set(Results.STATUS_RESULT, 'Badly formated username: $u');
		}
		else{
			_result.set(Results.STATUS_RESULT, 'Cannot connect. username given but empty');
		}
		return "";
	}
	/**
	 *
	 */
	function info_debug():Void
	{
		_result.set(Results.STATUS_RESULT, 'Listing all params and returned values' );
		_result.set(Params.PARAMS_PARAM, PARAMS_INFO );
		_result.set(Results.RESULTS_RESULT, RESULTS_INFO );
		Lib.println("<h2>Default config</h2>");
		try
		{

			Lib.dump(_config);
			Lib.println("<h3>Default sub attibutes</h3>");
			Lib.dump(_config.attributesSubs);
		}
		catch (e)
		{
			trace(e);
		}
	}

	function findUserSearchInParams():String
	{
		return if (_params.exists(Params.SEARCH_PARAM))
		{
			_params.get(Params.SEARCH_PARAM);
		}
		else if (_params.exists(Params.USERNAME_PARAM))
		{
			_params.get(Params.USERNAME_PARAM);
		}
		else if (_params.exists(Params.FINDSINGLE_PARAM))
		{
			_params.get(Params.FINDSINGLE_PARAM);
		}
		else
		{
			"";
		}
	}

	function createSearchString(s:String):String
	{
		//bruno.baudry@salt.ch
		//julieta vaz velho
		//Grzeskiewicz Daria Malgorzata
		//apeter
		return if ( ExpReg.STRING_TO_REG(ExpReg.EMAIL, "i").match(s))
			'${Attributes.mail}=$s';
		else if (ExpReg.STRING_TO_REG(ExpReg.SALT_NT, "i").match(s))
			'${Attributes.sAMAccountName}=$s';
		else if (ExpReg.STRING_TO_REG(ExpReg.CN, "i").match(s))
			_cnx.generateANDSearchFromAttributeAndList(s.split(" "), Attributes.cn, true);
		else "";
	}

	function getPeers():Void
	{
		if (_attributesType != null && _params.get(Params.ATTR_TYPE_PARAM) ==  Params.ATTR_TYPE_VALUE_SUB)
		{
			_result.set(Results.STATUS_RESULT, _result.get(Results.STATUS_RESULT) + '; Cannot find "${Results.PEERS_RESULT}" with attributes type as "${Params.ATTR_TYPE_VALUE_SUB}"');
		}
		else
		{
			var peers = _cnx.getPeers(_singleUserAttributes, _attributesType);
			if (peers == [])
			{
				_result.set(Results.STATUS_RESULT, _result.get(Results.STATUS_RESULT) + "; No ${Results.PEERS_RESULT} found");
			}
			else
			{
				_result.set(Results.PEERS_RESULT, peers);
			}
		}
	}

	function getBoss():Void
	{
		if (_attributesType != null && _params.get(Params.ATTR_TYPE_PARAM) == Params.ATTR_TYPE_VALUE_SUB)
		{
			_result.set(Results.STATUS_RESULT, _result.get(Results.STATUS_RESULT) + '; Cannot find "${Results.MANAGER_RESULT}" with attributes type as "${Params.ATTR_TYPE_VALUE_SUB}"');
		}
		else
		{
			var boss = _cnx.getBoss(_singleUserAttributes, _attributesType);
			//Lib.dump("boss is null 0");
			//Lib.dump(boss == null);
			//Lib.dump(boss);
			if (boss == null)
			{
				//serch non active
				//Lib.dump("boss is null 1");
				boss = _cnx.getBoss(_singleUserAttributes, _attributesType, true);
			}
			if (boss == null)
			{
				//Lib.dump("boss is null 2");
				_result.set(Results.STATUS_RESULT, _result.get(Results.STATUS_RESULT) + '; ${Results.MANAGER_RESULT} not found');
			}
			else _result.set(Results.MANAGER_RESULT, boss);
		}
	}

	function storeTeamTLList(list:String):Void
	{
		//store new list
		try
		{
			_cnx.setTeamTlList(list.urlDecode());
			_result.set(Results.STATUS_RESULT, "team_tl stored ok");
		}
		catch (e)
		{
			_result.set(Results.STATUS_RESULT, "Exception thrown when trying to write team_tl file ");
			_result.set(Results.DETAILS_RESULT, e.details);
			_result.set(Results.MESSAGE_RESULT, e.message);
		}
	}

	function getTeamList():Void
	{
		try
		{
			//var r = _cnx.getTeamTlList();
			_result.set(Results.TEAM_TL_RESULT, _cnx.getTeamTlList().urlEncode());

		}
		catch (e)
		{
			_result.set(Results.STATUS_RESULT, "Exception thrown when trying to fetch team_tl file");
			_result.set(Results.DETAILS_RESULT, e.details);
			_result.set(Results.MESSAGE_RESULT, e.message);
		}
	}

	function generateImageThumbnail():Void
	{
		var nt:String = _singleUserAttributes.get(Attributes.sAMAccountName.toLowerCase());
		Global.header('Content-Type: image/jpeg');
		Global.header('Content-Disposition: inline; filename=${nt)}.jpg');
		//Lib.println('data:image/jpeg;base64,${_thumbnailEncoded}');
		//Lib.println('<img src="data:image/jpeg;base64,${_thumbnailEncoded}"/>');
		//Lib.println(StringTools.urlDecode(_singleUserAttributes.get(Attributes.thumbnailphoto)));
		if (_singleUserAttributes.exists(Attributes.thumbnailphoto))
			Lib.println(
				Base64.decode(
					_singleUserAttributes.get(Attributes.thumbnailphoto)
				)
			);
		else
		{
			var bg = StringUtils.strHexToRGBInt(_params.exists(Params.BG_COLOR)?_params.get(Params.BG_COLOR):DEFAULT_BG);
			var txtColor = StringUtils.strHexToRGBInt(_params.exists(Params.TEXT_COLOR)?_params.get(Params.TEXT_COLOR):DEFAULT_TEXT_COLOR);
			var initials = nt.indexOf("sp_") == 0 ? nt.substr(3, 2): nt.substr(0, 2);
			var image = Gd.imagecreatetruecolor(64, 64);
			var bgColor = Gd.imagecolorallocatealpha(image, bg.r, bg.g, bg.b, bg.alpha);
			Gd.imagefill(image, 0, 0, bgColor);
			var textColorPhp = Gd.imagecolorallocatealpha(image, txtColor.r, txtColor.g,txtColor.b,txtColor.alpha);
			Gd.imagettftext(image, 24,0, 13, 45, textColorPhp, "/home/qook/app/qook/commonlibs/login/JetBrainsMono-ExtraBold.ttf", initials.toUpperCase());
			Gd.imagejpeg(image);
			Gd.imagedestroy(image);

		}
	}

}
#if php
@:phpGlobal
extern class Gd
{
	public static function imagecreatetruecolor(w:Int, h:Int): Dynamic;
	public static function imagecopyresampled(dst_image:Dynamic, src_image:Dynamic, dst_x:Int, dst_y:Int, src_x:Int, src_y:Int, dst_w:Int, dst_h:Int, src_w:Int, src_h:Int): Bool;
	public static function imagedestroy(_image:Dynamic): Bool;
	public static function imagegif(_image:Dynamic,?_to:Dynamic): Bool;
	public static function imagejpeg(_image:Dynamic,?_to:Dynamic,?quality:Int): Bool;
	public static function imagepng(_image:Dynamic,?_to:Dynamic, ?quality:Int): Bool;
	public static function imagebmp(_image:Dynamic,?_to:Dynamic): Bool;
	public static function imagealphablending(image: Dynamic, blendmode: Bool): Bool;
	public static function imagesavealpha(image: Dynamic, saveFlag: Bool): Bool;
	public static function imagecolorallocatealpha(image: Dynamic, red: Int, green: Int, blue: Int, alpha: Int): Int;
	public static function imagefilledrectangle(image: Dynamic, x1: Int, y1: Int, x2: Int, y2: Int, color: Int): Bool;
	public static function imagefill(image: Dynamic, x: Int, y: Int, color: Int): Bool;
	public static function imagettftext(image: Dynamic, size:Float, angle:Float,x:Int,y:Int,color:Int,font_filename:String,tetx:String,?options:Dynamic):Dynamic;

	/*static public function imagecreate(w:Int, h:Int): Dynamic;
	{

	}*/
}
#end