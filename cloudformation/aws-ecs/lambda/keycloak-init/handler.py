"""
Lambda function to initialize Keycloak realm for MCP Gateway.
Used as a CloudFormation Custom Resource.
"""
import json
import urllib.request
import urllib.parse
import urllib.error
import ssl
import boto3
import cfnresponse

def get_admin_token(keycloak_url, admin_user, admin_password):
    """Get admin access token from Keycloak."""
    url = f"{keycloak_url}/realms/master/protocol/openid-connect/token"
    data = urllib.parse.urlencode({
        'username': admin_user,
        'password': admin_password,
        'grant_type': 'password',
        'client_id': 'admin-cli'
    }).encode('utf-8')
    
    req = urllib.request.Request(url, data=data, method='POST')
    req.add_header('Content-Type', 'application/x-www-form-urlencoded')
    
    ctx = ssl.create_default_context()
    with urllib.request.urlopen(req, context=ctx, timeout=30) as response:
        result = json.loads(response.read().decode('utf-8'))
        return result.get('access_token')

def keycloak_request(url, token, method='GET', data=None):
    """Make authenticated request to Keycloak Admin API."""
    req = urllib.request.Request(url, method=method)
    req.add_header('Authorization', f'Bearer {token}')
    req.add_header('Content-Type', 'application/json')
    
    if data:
        req.data = json.dumps(data).encode('utf-8')
    
    ctx = ssl.create_default_context()
    try:
        with urllib.request.urlopen(req, context=ctx, timeout=30) as response:
            if response.status in [200, 201]:
                try:
                    return json.loads(response.read().decode('utf-8'))
                except:
                    return {}
            return {}
    except urllib.error.HTTPError as e:
        if e.code == 409:  # Conflict - already exists
            return {'exists': True}
        raise

def realm_exists(keycloak_url, token, realm):
    """Check if realm already exists."""
    try:
        keycloak_request(f"{keycloak_url}/admin/realms/{realm}", token)
        return True
    except urllib.error.HTTPError as e:
        if e.code == 404:
            return False
        raise

def handler(event, context):
    """CloudFormation Custom Resource handler."""
    print(f"Event: {json.dumps(event)}")
    
    request_type = event.get('RequestType')
    properties = event.get('ResourceProperties', {})
    
    # Extract parameters
    keycloak_url = properties.get('KeycloakUrl')
    registry_url = properties.get('RegistryUrl')
    admin_secret_arn = properties.get('AdminSecretArn')
    client_secret_arn = properties.get('ClientSecretArn')
    
    # For Delete, just return success
    if request_type == 'Delete':
        cfnresponse.send(event, context, cfnresponse.SUCCESS, {})
        return
    
    try:
        # Get admin credentials from Secrets Manager
        secrets = boto3.client('secretsmanager')
        admin_secret = json.loads(
            secrets.get_secret_value(SecretId=admin_secret_arn)['SecretString']
        )
        admin_user = admin_secret.get('username', 'admin')
        admin_password = admin_secret.get('password')
        
        print(f"Initializing Keycloak at {keycloak_url}")
        
        # Get admin token
        token = get_admin_token(keycloak_url, admin_user, admin_password)
        if not token:
            raise Exception("Failed to get admin token")
        print("Got admin token")
        
        realm = 'mcp-gateway'
        
        # Create realm if not exists
        if not realm_exists(keycloak_url, token, realm):
            print("Creating realm...")
            keycloak_request(
                f"{keycloak_url}/admin/realms",
                token,
                method='POST',
                data={
                    'realm': realm,
                    'enabled': True,
                    'registrationAllowed': False,
                    'loginWithEmailAllowed': True,
                    'duplicateEmailsAllowed': False,
                    'resetPasswordAllowed': True
                }
            )
            print("Realm created")
        else:
            print("Realm already exists")
        
        # Create web client
        print("Creating web client...")
        keycloak_request(
            f"{keycloak_url}/admin/realms/{realm}/clients",
            token,
            method='POST',
            data={
                'clientId': 'mcp-gateway-web',
                'name': 'MCP Gateway Web Client',
                'enabled': True,
                'clientAuthenticatorType': 'client-secret',
                'redirectUris': [
                    f"{registry_url}/oauth2/callback/keycloak",
                    f"{registry_url}/*",
                    "http://localhost:7860/*",
                    "http://localhost:8888/*"
                ],
                'webOrigins': [registry_url, "http://localhost:7860", "+"],
                'protocol': 'openid-connect',
                'standardFlowEnabled': True,
                'directAccessGrantsEnabled': True,
                'publicClient': False
            }
        )
        
        # Create groups
        print("Creating groups...")
        for group in ['mcp-registry-admin', 'mcp-registry-user', 'mcp-servers-unrestricted']:
            keycloak_request(
                f"{keycloak_url}/admin/realms/{realm}/groups",
                token,
                method='POST',
                data={'name': group}
            )
        
        # Create admin user
        print("Creating admin user...")
        keycloak_request(
            f"{keycloak_url}/admin/realms/{realm}/users",
            token,
            method='POST',
            data={
                'username': 'admin',
                'email': 'admin@example.com',
                'enabled': True,
                'emailVerified': True,
                'firstName': 'Admin',
                'lastName': 'User',
                'credentials': [{'type': 'password', 'value': 'changeme', 'temporary': False}]
            }
        )
        
        # Get admin user ID and assign to groups
        users = keycloak_request(
            f"{keycloak_url}/admin/realms/{realm}/users?username=admin",
            token
        )
        if users and len(users) > 0:
            admin_id = users[0].get('id')
            groups = keycloak_request(
                f"{keycloak_url}/admin/realms/{realm}/groups",
                token
            )
            for group in groups:
                if group.get('name') in ['mcp-registry-admin', 'mcp-servers-unrestricted']:
                    keycloak_request(
                        f"{keycloak_url}/admin/realms/{realm}/users/{admin_id}/groups/{group['id']}",
                        token,
                        method='PUT'
                    )
        
        # Generate and store client secret
        print("Generating client secret...")
        clients = keycloak_request(
            f"{keycloak_url}/admin/realms/{realm}/clients?clientId=mcp-gateway-web",
            token
        )
        if clients and len(clients) > 0:
            client_uuid = clients[0].get('id')
            
            # Generate new secret
            keycloak_request(
                f"{keycloak_url}/admin/realms/{realm}/clients/{client_uuid}/client-secret",
                token,
                method='POST'
            )
            
            # Get the secret
            secret_response = keycloak_request(
                f"{keycloak_url}/admin/realms/{realm}/clients/{client_uuid}/client-secret",
                token
            )
            client_secret = secret_response.get('value')
            
            if client_secret:
                # Store in Secrets Manager
                print("Storing client secret in Secrets Manager...")
                secrets.update_secret(
                    SecretId=client_secret_arn,
                    SecretString=json.dumps({'client_secret': client_secret})
                )
                print("Client secret stored")
        
        print("Keycloak initialization complete!")
        cfnresponse.send(event, context, cfnresponse.SUCCESS, {
            'Realm': realm,
            'ClientId': 'mcp-gateway-web'
        })
        
    except Exception as e:
        print(f"Error: {str(e)}")
        cfnresponse.send(event, context, cfnresponse.FAILED, {
            'Error': str(e)
        })
