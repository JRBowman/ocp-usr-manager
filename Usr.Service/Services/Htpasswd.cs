using System.Diagnostics;

namespace Usr.Service.Services
{
    public class Htpasswd
    {
        public string ContentDirectory => _contentDirectory;
        private string _contentDirectory = "Artifacts";

        public string HtpasswdFilePath => _htpasswdFilePath;

        private string _htpasswdFile = "";
        private string _htpasswdFilePath = "";

        private bool _htpasswdCreated = false;

        public Htpasswd()
        {
            _htpasswdFilePath = $"{ContentDirectory}/users.htpasswd";
            _htpasswdCreated = File.Exists(_htpasswdFilePath);
        }

        public Htpasswd(string contentDirectory = "Artifacts")
        {
            _contentDirectory = contentDirectory;
            _htpasswdFilePath = $"{_contentDirectory}/users.htpasswd";
            _htpasswdCreated = File.Exists(_htpasswdFilePath);
        }

        #region HTPasswd Methods:

        public async Task<bool> SetHtpasswdFile(string htpasswdData)
        {
            _htpasswdFile = htpasswdData;

            await File.WriteAllTextAsync(_htpasswdFilePath, htpasswdData);

            _htpasswdCreated = File.Exists(_htpasswdFilePath);
            return _htpasswdCreated;
        }

        public async Task<string> CreateHtpasswdFile(string username, string password)
        {
            return await Command("-c", "-B", "-b", _htpasswdFilePath, username, password);
        }

        public async Task<string> UpsertUser(string username, string password)
        {
            // Short Circuit - Create HTPasswd File if it doesn't exist yet:
            if (!_htpasswdCreated) return await CreateHtpasswdFile(username, password);

            return await Command("-B", "-b", _htpasswdFilePath, username, password);
        }

        #endregion

        #region Internal Command Execution:

        private async Task<string> Command(params string[] args)
        {
            string rawResult = "";

            using (Process proc = new())
            {
                proc.StartInfo.FileName = "htpasswd";
                proc.StartInfo.Arguments = string.Join(' ', args);
                proc.StartInfo.UseShellExecute = false;
                proc.StartInfo.RedirectStandardOutput = true;
                proc.Start();

                rawResult = await proc.StandardOutput.ReadToEndAsync();

                await proc.WaitForExitAsync();
            }

            return rawResult;
        }

        #endregion

    }
}
