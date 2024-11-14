using k8s;
using k8s.Autorest;
using Microsoft.AspNetCore.Http.HttpResults;

namespace Usr.Service.Services
{
    public class OpenShiftClient
    {

        private readonly KubernetesClientConfiguration _clientConfiguration;
        public KubernetesClientConfiguration KubeConfig => _clientConfiguration;

        private readonly IKubernetes _client;
        public IKubernetes Client => _client;

        public OpenShiftClient()
        {
            // Instantiate KubeConfig and KubeClient:
            _clientConfiguration = KubernetesClientConfiguration.InClusterConfig();
            _client = new Kubernetes(_clientConfiguration);

            Console.WriteLine($"OpenShift DI Initialized for Context: {_clientConfiguration.CurrentContext} using serviceaccount: {_clientConfiguration.Username}...");
        }

        public async Task<string> UpdateHTPasswd(string htpassPath)
        {
            // 1.) Get the Current HTPasswd Secret in `openshift-config`:
            var htpasswdSecret = await _client.CoreV1.ReadNamespacedSecretAsync("users", "openshift-config");
            bool exists = htpasswdSecret != null;

            HttpOperationResponse result;

            if (!exists)
            {
                var htpassData = new Dictionary<string, string>();
                htpassData.Add("htpasswd", await File.ReadAllTextAsync(htpassPath));

                htpasswdSecret = new k8s.Models.V1Secret()
                {
                    StringData = htpassData
                };

                result = await _client.CoreV1.CreateNamespacedSecretWithHttpMessagesAsync(htpasswdSecret, "openshift-config");
            }
            else
            {

                result = await _client.CoreV1.ReplaceNamespacedSecretWithHttpMessagesAsync(htpasswdSecret, "users", "openshift-config");
            }



            if (result == null) return "Failed to execute the Operation.";

            if (!result.Response.IsSuccessStatusCode) return result.Response.ReasonPhrase ?? "Failed to execute the Operation.";

            return "Successfully Applied HTPasswd content in 'openshift-config' namespace using Secret 'Users'.";
        }


    }
}
