import subprocess

def run_sail_align(config, session):
    subprocess.call('sail_align -i {} -t {} -w {} -e {} -c ./{}'.format(session.get('audio'),
                    session.get('trascript'),
                    config['sailalign_wdir'],
                    config['sailalign_expid'],
                    config['sailalign_config']),shell=True)


