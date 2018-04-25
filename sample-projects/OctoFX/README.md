OctoFX is a sample project. Go to the [public GitHub samples](https://github.com/OctopusSamples/OctoFX) to learn more.

The `OctopusExport` directory contains files exported from an Octopus server, that you can import. To import:

```bash
"Octopus.Migrator.exe" import --directory "OctopusExport" --password "Password01!"
```

## Set up

At the moment you will need to manually create the databases, and configure your SQL Server to allow access for the built-in `Network Service` account. You can use the following SQL:

```sql
create database OctoFX_Development
create database OctoFX_Test
create database OctoFX_Production
GO

USE [master]
GO
CREATE LOGIN [NT AUTHORITY\NETWORK SERVICE] FROM WINDOWS WITH DEFAULT_DATABASE=[master]
GO
ALTER SERVER ROLE [sysadmin] ADD MEMBER [NT AUTHORITY\NETWORK SERVICE]
GO
```

You will also need a local Tentacle, listening on port 10933. TODO: I think we might need to store the Octopus 
certificate to use?

## Changing it

If you want to make changes to the project, the best way is to import it to a fresh Octopus, make the change, then export it again. To export it, do:

```bash
"Octopus.Migrator.exe" partial-export --directory "OctopusExport" --password "Password01!" --project "OctoFX" --ignore-deployments
```

Then commit the differences to this Git repository.

(It's important to keep the password the same, so that sensitive variables don't show up as changed in Git)